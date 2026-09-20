#!/usr/bin/env python3
"""Replay mouse events in an isolated tmux; never access the desktop clipboard."""
import os,pty,subprocess,time,fcntl,termios,struct,re,tempfile,threading,select
from pathlib import Path
scratch=tempfile.TemporaryDirectory(prefix='tmux-mouse-test-')
sock=str(Path(scratch.name)/'socket')
config=Path(__file__).resolve().parents[2]/'tmux/tmux.conf.local'
def tm(*args):return subprocess.check_output(['tmux','-S',sock,*args],stderr=subprocess.STDOUT).decode()
m,s=pty.openpty();fcntl.ioctl(s,termios.TIOCSWINSZ,struct.pack('HHHH',24,80,0,0));p=None
stop_drain=threading.Event()
def drain_terminal():
 while not stop_drain.is_set():
  if select.select([m],[],[],0.1)[0]:
   try: os.read(m,65536)
   except OSError: return
drain_thread=threading.Thread(target=drain_terminal,daemon=True)
drain_thread.start()
try:
 left=tm('-f','/dev/null','new-session','-d','-P','-F','#{pane_id}','-s','test','-x','80','-y','24',"printf 'abcdefghijklmnopqrstuvwxyz\\n'; sleep 300").strip()
 right=tm('split-window','-h','-P','-F','#{pane_id}','-t',left,"printf 'abcdefghijklmnopqrstuvwxyz\\n'; sleep 300").strip()
 tm('set','-g','mouse','on');tm('set','-s','set-clipboard','off')
 p=subprocess.Popen(['tmux','-S',sock,'attach','-t','test'],stdin=s,stdout=s,stderr=s,env={**os.environ,'TERM':'xterm-256color'});time.sleep(.25)
 x=int(tm('display-message','-p','-t',right,'#{pane_left}'))+3
 for variant in ('before','after'):
  lines=[re.sub(r"run-shell -b '[^']*'", 'set-option -p @test_notice copied', l.split(' #!important')[0]) for l in config.read_text().splitlines() if l.startswith('bind -T ') and ('MouseDown1Pane' in l or 'MouseDragEnd1Pane' in l)]
  (Path(scratch.name)/'bindings.conf').write_text('\n'.join(lines)+'\n');tm('source',str(Path(scratch.name)/'bindings.conf'))
  if variant=='after':
   entry=[l.split(' #!important')[0] for l in config.read_text().splitlines() if l.startswith('bind -T root ') and ('MouseDown1Pane' in l or 'MouseDrag1Pane' in l)]
   (Path(scratch.name)/'entry.conf').write_text('\n'.join(entry)+'\n');tm('source',str(Path(scratch.name)/'entry.conf'))
  for mode in ('vi','emacs'):
   tm('set','-g','mode-keys',mode)
   for kind in ('click','same-cell motion','drag','gradual drag'):
    for pane in (left,right):
     tm('copy-mode','-t',pane);tm('send-keys','-X','-t',pane,'cancel');tm('set','-pu','-t',pane,'@test_notice')
    tm('select-pane','-t',left);tm('set-buffer','SENTINEL');time.sleep(.6)
    events=f'\x1b[<0;{x};1M'
    end=x+5 if kind in ('drag','gradual drag') else x
    if kind=='gradual drag':events+=f'\x1b[<32;{x};1M'
    if kind!='click':events+=f'\x1b[<32;{end};1M'
    events+=f'\x1b[<0;{end};1m';os.write(m,events.encode());time.sleep(.15)
    result=tm('save-buffer','-');notice=tm('display-message','-p','-t',right,'#{@test_notice}').strip()
    active=tm('display-message','-p','#{pane_id}').strip()
    print(variant,mode,kind,repr(result),'notice='+repr(notice),'switched='+str(active==right))
    assert active==right
    print('target mode:',tm('display-message','-p','-t',right,'#{pane_in_mode}').strip())
    if variant=='after':
     if kind in ('drag','gradual drag'):assert result!='SENTINEL' and len(result)>1 and notice=='copied'
     else:assert result=='SENTINEL' and not notice and tm('display-message','-p','-t',right,'#{pane_in_mode}').strip()=='0'
 # Wheel still enters copy mode; applications requesting mouse input keep it.
 tm('copy-mode','-t',right);tm('send-keys','-X','-t',right,'cancel');time.sleep(.6)
 os.write(m,f'\x1b[<64;{x};1M'.encode());time.sleep(.15)
 assert tm('display-message','-p','-t',right,'#{pane_in_mode}').strip()=='1'
 print('wheel entry: PASS')
 tm('respawn-pane','-k','-t',right,"printf '\\033[?1002h'; sleep 300");time.sleep(.2)
 assert tm('display-message','-p','-t',right,'#{mouse_any_flag}').strip()=='1'
 os.write(m,f'\x1b[<0;{x};1M\x1b[<32;{x+5};1M\x1b[<0;{x+5};1m'.encode());time.sleep(.15)
 assert tm('display-message','-p','-t',right,'#{pane_in_mode}').strip()=='0'
 print('mouse application keeps input: PASS')

finally:
 try:tm('kill-server')
 except:pass
 if p:p.wait()
 stop_drain.set();drain_thread.join(timeout=1);os.close(m);os.close(s);scratch.cleanup()
