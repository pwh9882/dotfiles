#!/usr/bin/env python3
"""Real Git/working-tree integration tests; all remotes and homes are temporary."""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'bin'


class Publishing(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='wiki-publish-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_CONFIG_NOSYSTEM='1', GIT_TERMINAL_PROMPT='0',
                        LLM_WIKI_NO_KICK='1')
        self.remote = self.root / 'remote.git'
        self.git(self.root, 'init', '--bare', str(self.remote))
        seed = self.root / 'seed'
        self.git(self.root, 'init', '-b', 'main', str(seed))
        self.git(seed, 'config', 'user.name', 'Test')
        self.git(seed, 'config', 'user.email', 'test@example.invalid')
        for name, body in {'a.md':'alpha\n', 'b.md':'beta\n',
                           'log.md':'# History\n\nold entry\n',
                           'state.md':'port: 8000\n',
                           'shared.md':'first\n\nsecond\n\nthird\n'}.items():
            (seed / name).write_text(body)
        (seed/'instances').mkdir()
        for instance in ['publisher','worker','other']:
            (seed/'instances'/(instance+'.md')).write_text('---\ninstance_id: '+instance+'\nhostname: test-host\n---\n')
        self.git(seed, 'add', '.')
        self.git(seed, 'commit', '-m', 'baseline')
        self.git(seed, 'remote', 'add', 'origin', str(self.remote))
        self.git(seed, 'push', '-u', 'origin', 'main')
        self.git(self.remote, 'symbolic-ref', 'HEAD', 'refs/heads/main')
        self.clients = {}
        for name, role in [('publisher','publisher'), ('worker','source'), ('other','source')]:
            home = self.root / name
            home.mkdir()
            wiki = home / 'wiki'
            self.git(home, 'clone', str(self.remote), str(wiki))
            fake = home / 'bin'
            fake.mkdir()
            identity = fake / 'llm-instance'
            identity.write_text('#!/bin/sh\nprintf "%s\\n" "' + name + '"\n')
            identity.chmod(0o755)
            env = dict(self.env, HOME=str(home), PATH=str(fake)+os.pathsep+str(BIN)+os.pathsep+os.environ['PATH'],
                       LLM_WIKI_DIR=str(wiki), LLM_WIKI_PUBLISH_CONFIG=str(home/'config.json'),
                       LLM_WIKI_STATE_DIR=str(home/'state'), LLM_WIKI_ACTOR='test-agent',
                       CODEX_THREAD_ID=name+'-session')
            self.clients[name] = (wiki, env)
            self.cmd(name, 'setup', '--role', role)

    def git(self, cwd, *args, check=True):
        return subprocess.run(['git','-c','commit.gpgsign=false','-C',str(cwd),*args],
                              env=self.env, text=True, capture_output=True, check=check)

    def cmd(self, who, *args, check=True):
        result = subprocess.run([str(BIN/'llm-wiki-git'), *args],
                                env=self.clients[who][1], text=True, capture_output=True)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        return result

    def edit(self, who, changes, task=None):
        path = self.root / ('changes-'+os.urandom(6).hex()+'.json')
        path.write_text(json.dumps(changes))
        args = ['edit','--summary','record '+who+' work','--changes',str(path)]
        if task:
            args += ['--id',task]
        return json.loads(self.cmd(who,*args).stdout)

    def show(self, path):
        return self.git(self.remote,'show','main:'+path).stdout

    def publish(self, *sources):
        for source in sources:
            self.cmd(source,'publish')
        self.cmd('publisher','publish')

    def test_unrelated_dirty_files_never_require_stash(self):
        wiki, _ = self.clients['worker']
        (wiki/'b.md').write_text('unfinished other work\n')
        before_head = self.git(wiki,'rev-parse','HEAD').stdout
        event = self.edit('worker',[{'path':'a.md','old':'alpha','new':'completed'}])
        self.assertTrue(event['commit'])
        self.assertEqual((wiki/'a.md').read_text(),'completed\n')
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'completed\n')
        self.assertEqual(self.show('b.md'),'beta\n')
        self.assertEqual((wiki/'b.md').read_text(),'unfinished other work\n')
        self.assertEqual(self.git(wiki,'rev-parse','HEAD').stdout,before_head)
        self.assertEqual(self.git(wiki,'stash','list').stdout,'')
        log = self.git(self.remote,'log','-1','--format=%B').stdout
        self.assertIn('Wiki-Instance: worker',log)
        self.assertIn('Wiki-Session: worker-session',log)

    def test_received_changes_are_not_attributed_to_receiver(self):
        first = self.edit('worker',[{'path':'shared.md','old':'first','new':'worker first'}])
        # Simulate LiveSync propagating bytes without Git metadata.
        (self.clients['other'][0]/'shared.md').write_bytes((self.clients['worker'][0]/'shared.md').read_bytes())
        second = self.edit('other',[{'path':'shared.md','old':'third','new':'other third'}])
        self.publish('other','worker')
        self.assertEqual(self.show('shared.md'),'worker first\n\nsecond\n\nother third\n')
        commits = self.git(self.remote,'log','--format=%H','--grep=Wiki-Submission:').stdout.splitlines()
        self.assertEqual(len(commits),2)
        for commit in commits:
            patch = self.git(self.remote,'show','--format=%B',commit).stdout
            if second['id'] in patch:
                self.assertIn('+other third',patch)
                self.assertNotIn('+worker first',patch)
        self.assertNotEqual(first['id'],second['id'])

    def test_parallel_log_insertions_merge_and_keep_both_authors(self):
        self.edit('worker',[{'path':'log.md','old':'old entry','new':'worker entry\n\nold entry'}])
        self.edit('other',[{'path':'log.md','old':'old entry','new':'other entry\n\nold entry'}])
        self.publish('worker','other')
        self.assertIn('worker entry',self.show('log.md'))
        self.assertIn('other entry',self.show('log.md'))
        self.assertEqual(self.show('log.md').count('old entry'),1)

    def test_conflict_does_not_block_independent_work(self):
        self.edit('worker',[{'path':'state.md','old':'8000','new':'8080'}])
        self.publish('worker')
        conflict = self.edit('other',[{'path':'state.md','old':'8000','new':'9090'}])
        self.edit('other',[{'path':'b.md','old':'beta','new':'independent'}])
        self.publish('other')
        self.assertEqual(self.show('state.md'),'port: 8080\n')
        self.assertEqual(self.show('b.md'),'independent\n')
        status = json.loads(self.cmd('publisher','status','--json').stdout)
        self.assertIn(conflict['id'],[x['id'] for x in status['blocked']])
        self.assertNotIn('<<<<<<<',self.show('state.md'))
        # Publisher must never rewrite the live vault during integration.
        self.assertEqual((self.clients['publisher'][0]/'state.md').read_text(),'port: 8000\n')

    def test_outage_keeps_local_commit_and_retry_is_idempotent(self):
        unavailable = self.root/'remote-offline.git'
        self.remote.rename(unavailable)
        event = self.edit('worker',[{'path':'a.md','old':'alpha','new':'offline change'}],task='1'*32)
        self.assertTrue(event['commit'])
        self.assertNotEqual(self.cmd('worker','publish',check=False).returncode,0)
        unavailable.rename(self.remote)
        again = self.edit('worker',[{'path':'a.md','old':'alpha','new':'offline change'}],task='1'*32)
        self.assertEqual(event['commit'],again['commit'])
        self.publish('worker')
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'offline change\n')
        count = self.git(self.remote,'rev-list','--count','--all','--grep=Wiki-Submission: '+event['id']).stdout.strip()
        self.assertEqual(count,'1')
        self.cmd('worker','publish')
        self.assertEqual(json.loads(self.cmd('worker','status','--json').stdout)['pending'],[])

    def test_local_concurrent_edits_preserve_both_commits(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(self.edit,'worker',[{'path':path,'old':old,'new':new}])
                       for path,old,new in [('a.md','alpha','A'),('b.md','beta','B')]]
            events = [f.result() for f in futures]
        self.assertEqual(len({x['id'] for x in events}),2)
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'A\n')
        self.assertEqual(self.show('b.md'),'B\n')

    def test_invalid_or_stale_edits_never_overwrite_files(self):
        wiki, _ = self.clients['worker']
        outside = self.root/'outside.md'
        outside.write_text('outside\n')
        (wiki/'link.md').symlink_to(outside)
        for changes in [[{'path':'a.md','old':'missing','new':'x'}],
                        [{'path':'../outside.md','old':'outside','new':'x'}],
                        [{'path':'link.md','old':'outside','new':'x'}]]:
            payload = self.root/'bad.json'
            payload.write_text(json.dumps(changes))
            self.assertNotEqual(self.cmd('worker','edit','--summary','bad','--changes',str(payload),check=False).returncode,0)
        self.assertEqual((wiki/'a.md').read_text(),'alpha\n')
        self.assertEqual(outside.read_text(),'outside\n')

    def test_same_line_concurrent_conflict_keeps_both_source_commits(self):
        events = [self.edit(who,[{'path':'state.md','old':'8000','new':port}])
                  for who,port in [('worker','8080'),('other','9090')]]
        self.publish('worker','other')
        status = json.loads(self.cmd('publisher','status','--json').stdout)
        self.assertEqual(len(status['blocked']),1)
        self.assertIn(self.show('state.md'),['port: 8080\n','port: 9090\n'])
        for who,event in zip(['worker','other'],events):
            state = Path(self.clients[who][1]['LLM_WIKI_STATE_DIR'])
            self.assertEqual(self.git(state/'objects.git','rev-parse','refs/wiki/local/'+event['id']).stdout.strip(),event['commit'])

    def test_crlf_and_unicode_paths_are_preserved(self):
        wiki, _ = self.clients['worker']
        name = '기록.md'
        self.edit('worker',[{'path':name,'create':'first\r\nsecond\r\n'}])
        self.edit('worker',[{'path':name,'old':'second','new':'second edited'}])
        self.assertEqual((wiki/name).read_bytes(),b'first\r\nsecond edited\r\n')
        self.publish('worker')
        raw = subprocess.check_output(['git','--git-dir',str(self.remote),'show','main:'+name],env=self.env)
        self.assertEqual(raw,b'first\r\nsecond edited\r\n')

    def test_create_delete_and_legacy_capture_are_explicit(self):
        self.edit('worker',[{'path':'new.md','create':'new knowledge\n'},
                            {'path':'b.md','before':'beta\n','after':None}])
        self.publish('worker')
        self.assertEqual(self.show('new.md'),'new knowledge\n')
        self.assertNotEqual(self.git(self.remote,'show','main:b.md',check=False).returncode,0)
        wiki, _ = self.clients['worker']
        (wiki/'a.md').write_text('old unrecorded work\n')
        self.cmd('worker','capture','--summary','import existing work','a.md')
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'old unrecorded work\n')
        self.assertIn('Wiki-Capture: existing',self.git(self.remote,'log','-1','--format=%B').stdout)

    def test_interrupted_live_write_is_recoverable_without_network(self):
        event = self.edit('worker',[{'path':'a.md','old':'alpha','new':'complete'}])
        wiki, env = self.clients['worker']
        manifest = Path(env['LLM_WIKI_STATE_DIR'])/'events'/(event['id']+'.json')
        saved = json.loads(manifest.read_text())
        saved['state'] = 'prepared'
        manifest.write_text(json.dumps(saved))
        (wiki/'a.md').write_text('alpha\n')
        self.publish('worker')
        self.assertEqual((wiki/'a.md').read_text(),'complete\n')
        self.assertEqual(self.show('a.md'),'complete\n')

    def test_legacy_commit_entry_point_keeps_identity_and_creates_authored_edit(self):
        changes = self.root/'wrapper-changes.json'
        changes.write_text(json.dumps([{'path':'a.md','old':'alpha','new':'wrapper'}]))
        result = subprocess.run([str(BIN/'llm-wiki-commit'),'record wrapper','--changes',str(changes)],
                                env=self.clients['worker'][1],text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.publish('worker')
        self.assertIn('worker: record wrapper',self.git(self.remote,'log','-1','--format=%B').stdout)

    def test_publish_retries_rejected_main_without_duplicate_commit(self):
        event = self.edit('worker',[{'path':'a.md','old':'alpha','new':'retry main'}])
        hook = self.remote/'hooks/pre-receive'
        hook.write_text('#!/bin/sh\nwhile read old new ref; do\n'
                        '  if [ "$ref" = refs/heads/main ] && [ ! -f retry-once ]; then\n'
                        '    touch retry-once\n    exit 1\n  fi\ndone\n')
        hook.chmod(0o755)
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'retry main\n')
        self.assertEqual(self.git(self.remote,'rev-list','--count','main','--grep=Wiki-Submission: '+event['id']).stdout.strip(),'1')

    def test_late_prerequisite_retries_in_same_drain(self):
        first = self.edit('worker',[{'path':'a.md','old':'alpha','new':'intermediate'}])
        second = self.edit('worker',[{'path':'a.md','old':'intermediate','new':'final'}])
        # Reverse the advertised clock ordering, as can happen across hosts.
        _, env = self.clients['worker']
        store = Path(env['LLM_WIKI_STATE_DIR'])/'objects.git'
        body = self.git(store,'show','-s','--format=%B',second['commit']).stdout
        import re
        body = re.sub(r'Wiki-Recorded-Ns: \d+','Wiki-Recorded-Ns: 1',body)
        tree = self.git(store,'rev-parse',second['commit']+'^{tree}').stdout.strip()
        parent = self.git(store,'rev-parse',second['commit']+'^').stdout.strip()
        revised = self.git(store,'-c','user.name=Test','-c','user.email=test@example.invalid',
                           'commit-tree',tree,'-p',parent,'-m',body).stdout.strip()
        manifest = Path(env['LLM_WIKI_STATE_DIR'])/'events'/(second['id']+'.json')
        saved = json.loads(manifest.read_text())
        saved['commit'] = revised
        manifest.write_text(json.dumps(saved))
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'final\n')
        self.assertEqual(json.loads(self.cmd('publisher','status','--json').stdout)['blocked'],[])

    def test_project_git_environment_cannot_redirect_wiki_writes(self):
        outside = self.root/'project-index'
        outside.write_text('preserve project staging\n')
        self.clients['worker'][1].update(GIT_INDEX_FILE=str(outside),GIT_DIR=str(self.root/'absent-project.git'))
        self.edit('worker',[{'path':'a.md','old':'alpha','new':'isolated'}])
        self.publish('worker')
        self.assertEqual(outside.read_text(),'preserve project staging\n')
        self.assertEqual(self.show('a.md'),'isolated\n')

    def test_adopt_preserves_existing_commit_author_message_and_live_files(self):
        wiki, _ = self.clients['worker']
        (wiki/'a.md').write_text('legacy work\n')
        self.git(wiki,'add','a.md')
        self.git(wiki,'-c','user.name=Original writer','-c','user.email=original@example.invalid',
                 'commit','-m','worker: original task description')
        original = self.git(wiki,'rev-parse','HEAD').stdout.strip()
        (wiki/'a.md').write_text('newer unfinished work\n')
        first = json.loads(self.cmd('worker','adopt',original).stdout)
        second = json.loads(self.cmd('worker','adopt',original).stdout)
        self.assertEqual(first['commit'],second['commit'])
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'legacy work\n')
        self.assertEqual((wiki/'a.md').read_text(),'newer unfinished work\n')
        self.assertEqual(self.git(self.remote,'log','-1','--format=%an').stdout.strip(),'Original writer')
        self.assertIn('worker: original task description',self.git(self.remote,'log','-1','--format=%B').stdout)

    def test_installed_status_wrapper_accepts_its_legacy_flags(self):
        result = subprocess.run([str(BIN/'llm-wiki-status')],env=self.clients['worker'][1],
                                text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout)['pending'],[])

    def test_own_insertion_survives_unpublished_context_and_another_published_log(self):
        wiki, _ = self.clients['worker']
        (wiki/'log.md').write_text('# History\n\nunpublished prior\n\nold entry\n')
        self.edit('other',[{'path':'log.md','old':'old entry','new':'published entry\n\nold entry'}])
        self.publish('other')
        self.edit('worker',[{'path':'log.md','old':'# History\n','new':'# History\n\nworker entry\n'}])
        self.publish('worker')
        text = self.show('log.md')
        self.assertIn('worker entry',text)
        self.assertIn('published entry',text)
        self.assertNotIn('unpublished prior',text)
        self.assertEqual(json.loads(self.cmd('publisher','status','--json').stdout)['blocked'],[])

    def test_background_publication_does_not_require_live_document_access(self):
        self.edit('worker',[{'path':'a.md','old':'alpha','new':'background'}])
        _,env = self.clients['worker']
        fake = Path(env['HOME'])/'bin/llm-instance'
        fake.write_text('#!/bin/sh\ncase "$LLM_WIKI_DIR" in\n'
                        ' */identity) printf "worker\\n" ;;\n'
                        ' *) echo "live Documents unavailable to daemon" >&2; exit 2 ;;\nesac\n')
        self.publish('worker')
        self.assertEqual(self.show('a.md'),'background\n')

    def test_existing_publisher_is_a_successful_noop_not_a_health_error(self):
        import fcntl
        state = Path(self.clients['worker'][1]['LLM_WIKI_STATE_DIR'])
        with (state/'publish.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            result = self.cmd('worker','publish')
            self.assertEqual(json.loads(result.stdout)['state'],'already-running')
        self.assertFalse((state/'health.json').exists())


if __name__ == '__main__':
    unittest.main()
