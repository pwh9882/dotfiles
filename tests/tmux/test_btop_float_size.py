import os,pty,fcntl,termios,struct,subprocess,tempfile,threading,time
from pathlib import Path
import shutil
with tempfile.TemporaryDirectory(prefix='btop-float-test-') as d:
 sock=d+'/socket'; t=shutil.which('tmux')
 def tm(*a): return subprocess.check_output([t,'-S',sock,*a],text=True).strip()
 master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',30,100,0,0))
 stop=threading.Event()
 def drain():
  import select
  while not stop.is_set():
   if select.select([master],[],[],.1)[0]:
    try:os.read(master,65536)
    except OSError:return
 th=threading.Thread(target=drain,daemon=True);th.start();p=None
 try:
  tm('-f','/dev/null','new-session','-d','-s','check','-x','100','-y','30','sleep 90')
  p=subprocess.Popen([t,'-S',sock,'attach','-t','check'],stdin=slave,stdout=slave,stderr=slave,env={**os.environ,'TERM':'xterm-256color'})
  time.sleep(.3)
  os.write(master,b'\x1b`');time.sleep(.4)
  assert len(tm('list-panes').splitlines())==1
  print('Before binding: key does not open a floating pane')
  config=Path(__file__).resolve().parents[2]/'tmux/tmux.conf.local'
  source=config.read_text(); start=source.index('# Option+` :'); end=source.index('%endif',start)+len('%endif')
  conf=Path(d)/'btop.conf';conf.write_text(source[start:end]+'\n')
  tm('set-option','-g','pane-border-status','bottom')
  tm('source-file',str(conf))
  sizes=[]
  for i in range(5):
   os.write(master,b'\x1b`');time.sleep(.4)
   sizes.append(tm('list-panes','-F','#{?pane_floating_flag,#{pane_width}x#{pane_height}@#{pane_left}:#{pane_top},}'))
   os.write(master,b'\x1b`');time.sleep(.2)
  print('Repeated sizes:',sizes)
  assert all(sizes),sizes
  assert len(set(sizes))==1,sizes
  os.write(master,b'\x1b`');time.sleep(.4)
  tm('resize-pane','-x','73','-y','19');tm('move-pane','-P','centre')
  expected=tm('list-panes','-F','#{?pane_floating_flag,#{pane_width}x#{pane_height}@#{pane_left}:#{pane_top},}')
  os.write(master,b'\x1b`');time.sleep(.2)
  os.write(master,b'\x1b`');time.sleep(.4)
  actual=tm('list-panes','-F','#{?pane_floating_flag,#{pane_width}x#{pane_height}@#{pane_left}:#{pane_top},}')
  assert actual==expected,(expected,actual)
  print('Manual resize and move preserved:',actual)

 finally:
  subprocess.run([t,'-S',sock,'kill-server'],capture_output=True)
  if p:p.wait(timeout=3)
  stop.set();th.join(timeout=1);os.close(master);os.close(slave)
