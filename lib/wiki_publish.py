#!/usr/bin/env python3
"""Authored live edits, durable local commits, and one publisher of wiki main.

The live vault is never a Git integration worktree. GitHub submission branches
are immutable envelopes; only the configured publisher advances main.
"""
import argparse
import contextlib
import difflib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

SUBMISSIONS = 'refs/heads/wiki-submit/'
ID = re.compile(r'^[a-f0-9]{32}$')
MARKERS = re.compile(r'^(<<<<<<< |>>>>>>> )', re.M)


class Failure(Exception):
    pass


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(prefix='.write-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_json(path, default=None):
    return json.loads(path.read_text()) if path.exists() else default


def read_text(path):
    # Keep CRLF and every byte of an existing UTF-8 file in its preimage.
    return path.read_bytes().decode('utf-8')


def metadata(value):
    value = str(value)
    if not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise Failure('Metadata must be nonempty and contain no control characters')
    return value


def identity():
    result = subprocess.run(['llm-instance'], capture_output=True, text=True, check=True)
    value = metadata(result.stdout.strip())
    if os.environ.get('LLM_WIKI_INSTANCE_ID', value) != value:
        raise Failure('LLM_WIKI_INSTANCE_ID disagrees with llm-instance')
    return value


def insert_merge(base, ours, theirs):
    """Merge only independently inserted lines, never choose between edits."""
    if any(x is None for x in (base, ours, theirs)):
        return None
    lines = base.splitlines(keepends=True)
    additions = []
    for version in (ours, theirs):
        changes = {}
        for tag, a, b, c, d in difflib.SequenceMatcher(None, lines, version.splitlines(keepends=True), autojunk=False).get_opcodes():
            if tag == 'equal':
                continue
            if tag != 'insert':
                return None
            changes[a] = version.splitlines(keepends=True)[c:d]
        additions.append(changes)
    merged = []
    for position in range(len(lines)+1):
        left, right = (a.get(position, []) for a in additions)
        merged.extend(left)
        if left != right:
            merged.extend(right)
        if position < len(lines):
            merged.append(lines[position])
    return ''.join(merged)


class Wiki:
    def __init__(self):
        self.wiki = Path(os.environ['LLM_WIKI_DIR']).resolve()
        self.config_path = Path(os.environ.get('LLM_WIKI_PUBLISH_CONFIG',
            str(Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))/'llm-wiki/publish.json')))
        self.config = read_json(self.config_path, {})
        self.state = Path(os.environ.get('LLM_WIKI_STATE_DIR', self.config.get('state',
            str(Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'llm-wiki')))).resolve()
        if self.state == self.wiki or self.wiki in self.state.parents:
            raise Failure('Publisher state must be outside the LiveSync wiki')
        self.repo = self.state/'objects.git'
        self.events = self.state/'events'
        self.receipts = self.state/'receipts'

    def git(self, *args, cwd=None, data=None, check=True, env=None):
        command = ['git','-c','commit.gpgsign=false','-c','core.autocrlf=false','-c','core.quotePath=false']
        command += ['-C',str(cwd)] if cwd else ['--git-dir',str(self.repo)]
        command += list(args)
        environ = dict(os.environ, GIT_TERMINAL_PROMPT='0', GIT_EDITOR='true')
        for name in ('GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE','GIT_COMMON_DIR',
                     'GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES','GIT_NAMESPACE'):
            environ.pop(name,None)
        if self.config:
            environ.update(GIT_COMMITTER_NAME=self.config['name'], GIT_COMMITTER_EMAIL=self.config['email'])
        if env:
            environ.update(env)
        try:
            result = subprocess.run(command, input=data.encode('utf-8') if data is not None else None, capture_output=True,
                                    env=environ, timeout=45)
        except subprocess.TimeoutExpired as exc:
            raise Failure('Git timed out; local commits remain recoverable') from exc
        result.stdout = result.stdout.decode('utf-8')
        result.stderr = result.stderr.decode('utf-8',errors='replace')
        if check and result.returncode:
            raise Failure(result.stderr.strip() or result.stdout.strip())
        return result

    @contextlib.contextmanager
    def lock(self, name, blocking=True):
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (self.state/(name+'.lock')).open('a') as stream:
            try:
                fcntl.flock(stream, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
            except BlockingIOError:
                raise Failure('Publisher already running; next automatic retry will check progress')
            yield

    def require_setup(self):
        if not self.config or not self.repo.exists():
            raise Failure('Run llm-wiki-git setup --role source (publisher on the integration instance) first')
        if str(self.wiki) != self.config['wiki']:
            raise Failure('Configured wiki differs from LLM_WIKI_DIR')
        if identity() != self.config['instance']:
            raise Failure('Publisher state belongs to a different instance')

    def setup(self, role, install_service=False):
        instance = identity()
        remote = self.git('remote','get-url','origin',cwd=self.wiki).stdout.strip()
        if self.config and (self.config['remote'] != remote or self.config['instance'] != instance):
            raise Failure('Existing publisher identity/remote differs; preserve state and review configuration')
        with self.lock('edit'):
            for directory in (self.events,self.receipts,self.state/'hooks'):
                directory.mkdir(parents=True, exist_ok=True, mode=0o700)
            if not self.repo.exists():
                self.git('init','--bare',str(self.repo),cwd=self.state)
                self.git('remote','add','origin',remote)
                self.git('config','core.hooksPath',str(self.state/'hooks'))
                self.git('config','core.fsync','committed')
            name = self.git('config','user.name',cwd=self.wiki,check=False).stdout.strip() or instance
            email = self.git('config','user.email',cwd=self.wiki,check=False).stdout.strip() or instance+'@llm-wiki.invalid'
            self.config = dict(schema=1, role=role, instance=instance, remote=remote,
                               name=name, email=email, wiki=str(self.wiki),state=str(self.state))
            self.fetch()
            self.git('symbolic-ref','HEAD','refs/remotes/origin/main')
            atomic_json(self.config_path,self.config)
        if install_service:
            self.install_service()
        return dict(instance=instance,role=role,state=str(self.state),service=install_service)

    def fetch(self, submissions=False):
        specs = ['+refs/heads/main:refs/remotes/origin/main']
        if submissions:
            specs += ['+'+SUBMISSIONS+'*:refs/remotes/submissions/*']
        self.git('fetch','--prune','origin',*specs)

    def path(self, name):
        path = PurePosixPath(name)
        if path.is_absolute() or not path.parts or any(p in ('.','..') or p.startswith('.') for p in path.parts):
            # The tracked ignore file is a deliberate exception.
            if name != '.gitignore':
                raise Failure('Unsafe wiki path: '+name)
        if '\\' in name or '\x00' in name or '\n' in name:
            raise Failure('Unsafe wiki path')
        target = self.wiki/name
        for part in [target, *target.parents]:
            if part == self.wiki:
                break
            if part.is_symlink():
                raise Failure('Symlinks are not authored wiki files: '+name)
        if target.exists() and not target.is_file():
            raise Failure('Not a regular wiki file: '+name)
        return target

    def blob(self, ref, path):
        result = self.git('show',ref+':'+path,check=False)
        return result.stdout if result.returncode == 0 else None

    def tree(self, base, contents):
        with tempfile.TemporaryDirectory(prefix='index-',dir=self.state) as temp:
            environ = {'GIT_INDEX_FILE':str(Path(temp)/'index'),'GIT_WORK_TREE':temp}
            self.git('read-tree',base,env=environ)
            for path, text in contents.items():
                if text is None:
                    self.git('update-index','--force-remove','--',path,env=environ)
                else:
                    oid = self.git('hash-object','-w','--stdin',data=text).stdout.strip()
                    mode = '100644'
                    entry = self.git('ls-tree',base,'--',path).stdout
                    if entry.startswith('100755 '):
                        mode = '100755'
                    self.git('update-index','--add','--cacheinfo',mode,oid,path,env=environ)
            return self.git('write-tree',env=environ).stdout.strip()

    def save_event(self, event):
        atomic_json(self.events/(event['id']+'.json'),event)

    def make_event(self, summary, before, after, event_id, task, capture=False, request=None):
        instance = identity()
        summary = metadata(summary)
        if not summary.startswith(instance+': '):
            summary = instance+': '+summary
        actor = metadata(os.environ.get('LLM_WIKI_ACTOR', 'codex' if os.environ.get('CODEX_THREAD_ID') else 'agent'))
        session = metadata(os.environ.get('CODEX_THREAD_ID') or os.environ.get('CLAUDE_SESSION_ID') or os.environ.get('LLM_WIKI_SESSION') or event_id)
        task = metadata(task or event_id)
        base = self.git('rev-parse','refs/remotes/origin/main').stdout.strip()
        before_tree = self.tree(base,before)
        author = dict(GIT_AUTHOR_NAME=self.config['name'],GIT_AUTHOR_EMAIL=self.config['email'])
        parent = self.git('commit-tree',before_tree,'-p',base,'-m','Source snapshot for '+event_id,env=author).stdout.strip()
        after_tree = self.tree(parent,after)
        if before_tree == after_tree:
            raise Failure('No changes to record')
        message = summary+'\n\n'+ '\n'.join([
            'Wiki-Submission: '+event_id,'Wiki-Instance: '+instance,'Wiki-Agent: '+actor,
            'Wiki-Session: '+session,'Wiki-Task: '+task,'Wiki-Recorded-Ns: '+str(time.time_ns()),
            'Wiki-Capture: '+('existing' if capture else 'authored')])
        commit = self.git('commit-tree',after_tree,'-p',parent,'-m',message,env=author).stdout.strip()
        self.git('update-ref','refs/wiki/local/'+event_id,commit)
        event = dict(id=event_id,commit=commit,created=time.time(),state='prepared',
                     instance=instance,task=task,paths=list(before),before=before,after=after,request=request)
        self.save_event(event)
        return event

    def apply_event(self, event):
        # A prepared transaction survives interruption. Recover only exact
        # preimages/postimages; never overwrite a third-party revision.
        for name in event['paths']:
            path = self.path(name)
            now = read_text(path) if path.exists() else None
            if now not in (event['before'][name],event['after'][name]):
                event.update(state='needs-recovery',error='Live file changed during edit: '+name)
                self.save_event(event)
                raise Failure(event['error']+'; both intended versions remain in local Git')
        for name in event['paths']:
            path = self.path(name)
            now = read_text(path) if path.exists() else None
            after = event['after'][name]
            if now == after:
                continue
            if now != event['before'][name]:
                raise Failure('Live edit raced with another writer; transaction retained: '+event['id'])
            if after is None:
                path.unlink()
            else:
                path.parent.mkdir(parents=True,exist_ok=True)
                mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
                fd, temporary = tempfile.mkstemp(prefix='.wiki-write-',dir=path.parent)
                try:
                    with os.fdopen(fd,'w') as stream:
                        stream.write(after)
                        stream.flush()
                        os.fsync(stream.fileno())
                    os.chmod(temporary,mode)
                    os.replace(temporary,path)
                finally:
                    if os.path.exists(temporary):
                        os.unlink(temporary)
            directory_fd = os.open(path.parent,os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        event['state'] = 'local'
        event.pop('error',None)
        self.save_event(event)

    def edit(self, summary, changes, event_id=None, task=None):
        self.require_setup()
        event_id = event_id or uuid.uuid4().hex
        if not ID.fullmatch(event_id):
            raise Failure('Submission ID must be 32 hexadecimal characters')
        with self.lock('edit'):
            previous = read_json(self.events/(event_id+'.json'))
            fingerprint = hashlib.sha256(json.dumps([summary,changes,task],sort_keys=True).encode()).hexdigest()
            if previous:
                if previous.get('request') != fingerprint:
                    raise Failure('Submission ID was already used for a different request')
                if previous['state'] == 'prepared':
                    self.apply_event(previous)
                self.kick()
                return self.result(previous)
            if not isinstance(changes,list) or not changes:
                raise Failure('Changes must be a nonempty JSON array')
            before, after = {}, {}
            for change in changes:
                name = change['path']
                path = self.path(name)
                if name not in before:
                    before[name] = read_text(path) if path.exists() else None
                    after[name] = before[name]
                if 'create' in change:
                    if after[name] is not None:
                        raise Failure('Create requires an absent file: '+name)
                    after[name] = change['create']
                elif 'before' in change and 'after' in change:
                    if after[name] != change['before']:
                        raise Failure('Expected file content differs: '+name)
                    after[name] = change['after']
                else:
                    old, new = change['old'],change['new']
                    if not old or after[name] is None or after[name].count(old) != 1:
                        raise Failure('Replacement must match exactly once: '+name)
                    after[name] = after[name].replace(old,new,1)
                if after[name] is not None and (not isinstance(after[name],str) or MARKERS.search(after[name])):
                    raise Failure('Invalid text or unresolved conflict markers: '+name)
            event = self.make_event(summary,before,after,event_id,task,request=fingerprint)
            self.apply_event(event)
        self.kick()
        return self.result(event)

    @staticmethod
    def result(event):
        return {key:event[key] for key in ('id','commit','state','paths')}

    def kick(self):
        if os.environ.get('LLM_WIKI_NO_KICK') == '1':
            return
        with (self.state/'publish.log').open('a') as log:
            subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'publish'],
                             stdin=subprocess.DEVNULL,stdout=log,stderr=log,
                             start_new_session=True,close_fds=True)

    def capture(self, summary, paths, base):
        """Explicit migration/import; complete selected files, not inferred authorship."""
        self.require_setup()
        with self.lock('edit'):
            base = self.git('rev-parse','--verify',base+'^{commit}').stdout.strip()
            before, after = {}, {}
            for name in paths:
                path = self.path(name)
                before[name] = self.blob(base,name)
                after[name] = read_text(path) if path.exists() else None
                if after[name] is not None and MARKERS.search(after[name]):
                    raise Failure('Unresolved conflict markers: '+name)
            event = self.make_event(summary,before,after,uuid.uuid4().hex,None,capture=True)
            event['state'] = 'local'
            self.save_event(event)
        self.kick()
        return self.result(event)

    def published(self):
        result = self.git('log','--format=%H%x09%(trailers:key=Wiki-Submission,valueonly)',
                          'refs/remotes/origin/main').stdout
        found = {}
        for line in result.splitlines():
            parts = line.split('\t',1)
            if len(parts) == 2 and ID.fullmatch(parts[1].strip()):
                found[parts[1].strip()] = parts[0]
        return found

    def adopt(self, reference):
        """Submit an existing unpublished commit without changing its live files."""
        self.require_setup()
        original = self.git('rev-parse','--verify',reference+'^{commit}',cwd=self.wiki).stdout.strip()
        event_id = hashlib.sha256((self.config['instance']+':'+original).encode()).hexdigest()[:32]
        with self.lock('edit'):
            existing = read_json(self.events/(event_id+'.json'))
            if existing:
                return self.result(existing)
            self.git('fetch',str(self.wiki),original+':refs/wiki/legacy/'+original)
            parents = self.git('rev-list','--parents','-n','1',original).stdout.split()
            if len(parents) != 2:
                raise Failure('Adopt requires a reviewed, single-parent historical commit')
            details = self.git('show','-s','--format=%an%x00%ae%x00%aI%x00%B',original).stdout.split('\x00',3)
            author = dict(zip(('GIT_AUTHOR_NAME','GIT_AUTHOR_EMAIL','GIT_AUTHOR_DATE'),details[:3]))
            body = details[3].rstrip()
            if re.search(r'^Wiki-Submission:',body,re.M):
                raise Failure('This commit already belongs to managed publication')
            paths = self.git('diff-tree','--no-commit-id','--name-only','-r',original).stdout.splitlines()
            for name in paths:
                self.path(name)
            tree = self.git('rev-parse',original+'^{tree}').stdout.strip()
            body += '\n\n'+'\n'.join(['Wiki-Submission: '+event_id,
                'Wiki-Instance: '+self.config['instance'],'Wiki-Agent: historical',
                'Wiki-Session: '+event_id,'Wiki-Task: legacy-'+original,
                'Wiki-Recorded-Ns: '+str(time.time_ns()),'Wiki-Capture: historical-commit',
                'Wiki-Original-Commit: '+original])
            commit = self.git('commit-tree',tree,'-p',parents[1],'-m',body,env=author).stdout.strip()
            self.git('update-ref','refs/wiki/local/'+event_id,commit)
            event = dict(id=event_id,commit=commit,created=time.time(),state='local',
                         instance=self.config['instance'],task='legacy-'+original,paths=paths,
                         before={n:self.blob(parents[1],n) for n in paths},
                         after={n:self.blob(original,n) for n in paths})
            self.save_event(event)
        self.kick()
        return self.result(event)

    def local_events(self):
        return [read_json(path) for path in sorted(self.events.glob('*.json'))]

    def sync_local(self, published):
        errors = []
        for event in self.local_events():
            if event['state'] == 'prepared':
                with self.lock('edit'):
                    try:
                        self.apply_event(event)
                    except Failure as exc:
                        errors.append(str(exc))
                        continue
            if event['state'] in ('needs-recovery','published'):
                continue
            if event['id'] in published:
                event.update(state='published',published_commit=published[event['id']],published_at=time.time())
                event.pop('error',None)
            else:
                result = self.git('push','origin',event['commit']+':'+SUBMISSIONS+event['id'],check=False)
                if result.returncode:
                    event['error'] = result.stderr.strip()
                    errors.append(event['error'])
                else:
                    event.update(state='submitted',submitted_at=time.time())
                    event.pop('error',None)
            self.save_event(event)
        return errors

    def safe_conflicts(self, worker, source):
        paths = self.git('diff','--name-only','--diff-filter=U',cwd=worker).stdout.splitlines()
        if not paths:
            return False
        resolutions = {}
        for name in paths:
            merged = insert_merge(self.blob(source+'^',name),
                                  self.blob(self.git('rev-parse','HEAD',cwd=worker).stdout.strip(),name),
                                  self.blob(source,name))
            if merged is None:
                return False
            resolutions[name] = merged
        for name, text in resolutions.items():
            target = worker/name
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_text(text)
            self.git('add','--',name,cwd=worker)
        return self.git('cherry-pick','--continue',cwd=worker,check=False).returncode == 0

    def integrate(self):
        for attempt in range(3):
            self.fetch(submissions=True)
            published = self.published()
            refs = self.git('for-each-ref','--format=%(objectname) %(refname)',
                            'refs/remotes/submissions/').stdout.splitlines()
            submissions = []
            for line in refs:
                source, ref = line.split(' ',1)
                event_id = ref.rsplit('/',1)[-1]
                if not ID.fullmatch(event_id):
                    continue
                body = self.git('show','-s','--format=%B',source).stdout
                if not re.search(r'^Wiki-Submission: '+event_id+r'$',body,re.M):
                    atomic_json(self.receipts/(event_id+'.json'),dict(id=event_id,state='blocked',error='Submission identity mismatch'))
                    continue
                parents = self.git('rev-list','--parents','-n','1',source).stdout.split()
                if len(parents) != 2:
                    continue
                recorded = re.search(r'^Wiki-Recorded-Ns: (\d+)$',body,re.M)
                timestamp = int(recorded.group(1)) if recorded else int(self.git('show','-s','--format=%at',source).stdout)*1000000000
                submissions.append((timestamp,event_id,source))
            submissions.sort()
            directory = Path(tempfile.mkdtemp(prefix='integrate-',dir=self.state))
            worker = directory/'tree'
            self.git('worktree','add','--detach',str(worker),'refs/remotes/origin/main')
            successful = []
            try:
                pending = submissions
                while pending:
                    deferred = []
                    for record in pending:
                        _, event_id, source = record
                        if event_id in published:
                            successful.append((event_id,source))
                            continue
                        result = self.git('cherry-pick','--allow-empty',source,cwd=worker,check=False)
                        if result.returncode:
                            unmerged = self.git('diff','--name-only','--diff-filter=U',cwd=worker).stdout
                            if unmerged and self.safe_conflicts(worker,source):
                                result.returncode = 0
                            elif not unmerged and self.git('diff','--cached','--quiet',cwd=worker,check=False).returncode == 0:
                                # Retain an authored receipt even if another
                                # published change already has the same effect.
                                result = self.git('commit','--allow-empty','-C',source,cwd=worker,check=False)
                            if result.returncode:
                                self.git('cherry-pick','--abort',cwd=worker,check=False)
                                atomic_json(self.receipts/(event_id+'.json'),dict(id=event_id,state='blocked',
                                    paths=unmerged.splitlines(),error='Conflicting content; original authored commit retained',updated=time.time()))
                                deferred.append(record)
                                continue
                        successful.append((event_id,source))
                    if len(deferred) == len(pending):
                        break
                    pending = deferred
                push = self.git('push','origin','HEAD:refs/heads/main',cwd=worker,check=False)
                if push.returncode:
                    if attempt == 2:
                        raise Failure('Main publication failed; submissions retained: '+push.stderr.strip())
                    continue
                self.fetch()
                confirmed = self.published()
                for event_id, source in successful:
                    if event_id not in confirmed:
                        continue
                    atomic_json(self.receipts/(event_id+'.json'),dict(id=event_id,state='published',
                        commit=confirmed[event_id],published_at=time.time()))
                    # Only delete the immutable envelope we actually published.
                    self.git('push','--force-with-lease='+SUBMISSIONS+event_id+':'+source,
                             'origin',':'+SUBMISSIONS+event_id,check=False)
                return
            finally:
                self.git('worktree','remove','--force',str(worker),check=False)
                shutil.rmtree(directory,ignore_errors=True)

    def publish(self):
        try:
            return self._publish()
        except Failure as exc:
            previous = read_json(self.state/'health.json',{})
            previous.update(last_attempt=time.time(),errors=[str(exc)])
            atomic_json(self.state/'health.json',previous)
            raise

    def _publish(self):
        self.require_setup()
        with self.lock('publish',blocking=False):
            # Only this runtime creates these directories, and the lock proves
            # there is no live integration process using them after a crash.
            for abandoned in self.state.glob('integrate-*'):
                if abandoned.is_dir() and not abandoned.is_symlink():
                    self.git('worktree','remove','--force',str(abandoned/'tree'),check=False)
                    shutil.rmtree(abandoned)
            self.fetch()
            errors = self.sync_local(self.published())
            if self.config['role'] == 'publisher':
                self.integrate()
            else:
                self.fetch()
            confirmed = self.published()
            for event in self.local_events():
                if event['id'] in confirmed and event['state'] != 'published':
                    event.update(state='published',published_commit=confirmed[event['id']],published_at=time.time())
                    event.pop('error',None)
                    self.save_event(event)
            atomic_json(self.state/'health.json',dict(last_attempt=time.time(),last_success=time.time() if not errors else None,errors=errors))
            if errors:
                raise Failure('Some submissions are retained locally for retry: '+'; '.join(errors))
        pending = [e for e in self.local_events() if e['state'] != 'published']
        blocked = [read_json(p) for p in self.receipts.glob('*.json')]
        return dict(history=self.git('rev-parse','refs/remotes/origin/main').stdout.strip(),
                    pending=len(pending),blocked=sum(e['state']=='blocked' for e in blocked))

    def status(self):
        self.require_setup()
        pending = []
        for event in self.local_events():
            if event['state'] != 'published':
                item = self.result(event)
                item['age_seconds'] = int(time.time()-event['created'])
                if event.get('error'):
                    item['error'] = event['error']
                pending.append(item)
        blocked = [read_json(path) for path in sorted(self.receipts.glob('*.json'))]
        with tempfile.TemporaryDirectory(prefix='inspect-',dir=self.state) as temp:
            env = {'GIT_INDEX_FILE':str(Path(temp)/'index'),'GIT_WORK_TREE':str(self.wiki)}
            self.git('read-tree','refs/remotes/origin/main',env=env)
            changed = self.git('diff','--name-only','refs/remotes/origin/main','--',env=env).stdout.splitlines()
            new = self.git('ls-files','--others','--exclude-standard',env=env).stdout.splitlines()
        return dict(instance=self.config['instance'],role=self.config['role'],pending=pending,
                    blocked=[x for x in blocked if x['state']=='blocked'],
                    live_files_differing_from_published_history=sorted(set(changed+new)),
                    health=read_json(self.state/'health.json',{}),
                    history=self.git('rev-parse','refs/remotes/origin/main').stdout.strip())

    def install_service(self):
        import plistlib
        command = [sys.executable,str(Path(__file__).resolve()),'publish']
        environ = dict(LLM_WIKI_DIR=str(self.wiki),LLM_WIKI_PUBLISH_CONFIG=str(self.config_path),
                       LLM_WIKI_STATE_DIR=str(self.state),PATH=str(Path.home()/'.local/bin')+os.pathsep+os.environ.get('PATH','/usr/bin:/bin'))
        if sys.platform == 'darwin':
            label = 'io.llm-wiki.publish'
            path = Path.home()/'Library/LaunchAgents'/ (label+'.plist')
            path.parent.mkdir(parents=True,exist_ok=True)
            with path.open('wb') as stream:
                plistlib.dump(dict(Label=label,ProgramArguments=command,StartInterval=30,RunAtLoad=True,
                                  EnvironmentVariables=environ,StandardOutPath=str(self.state/'publish.log'),
                                  StandardErrorPath=str(self.state/'publish.log')),stream)
            target = 'gui/'+str(os.getuid())
            subprocess.run(['launchctl','bootout',target+'/'+label],capture_output=True)
            subprocess.run(['launchctl','bootstrap',target,str(path)],check=True,capture_output=True)
        elif sys.platform.startswith('linux'):
            def quote(value):
                return '"'+value.replace('\\','\\\\').replace('"','\\"').replace('%','%%')+'"'
            directory = Path.home()/'.config/systemd/user'
            directory.mkdir(parents=True,exist_ok=True)
            envlines = '\n'.join('Environment='+quote(k+'='+v) for k,v in environ.items())
            (directory/'llm-wiki-publish.service').write_text('[Unit]\nDescription=Publish authored wiki changes\n[Service]\nType=oneshot\n'+envlines+'\nExecStart='+' '.join(map(quote,command))+'\n')
            (directory/'llm-wiki-publish.timer').write_text('[Unit]\nDescription=Retry wiki publication\n[Timer]\nOnBootSec=15\nOnUnitInactiveSec=30\nUnit=llm-wiki-publish.service\n[Install]\nWantedBy=timers.target\n')
            subprocess.run(['systemctl','--user','daemon-reload'],check=True,capture_output=True)
            subprocess.run(['systemctl','--user','enable','--now','llm-wiki-publish.timer'],check=True,capture_output=True)
        else:
            raise Failure('Automatic retry installation supports macOS and Linux')


def main():
    wiki = Wiki()
    argv = sys.argv[1:] or ['status']
    # Preserve the established llm-wiki-commit identity/prefix entry point.
    if argv[0] == 'commit':
        if len(argv) < 4 or argv[1] != '-m' or '--changes' not in argv:
            raise Failure('Use llm-wiki-commit "summary" --changes /path/to/edits.json; managed commits never infer authorship from a shared index')
        argv = ['edit','--summary',argv[2],*argv[3:]]
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command',required=True)
    setup = sub.add_parser('setup')
    setup.add_argument('--role',choices=['source','publisher'],required=True)
    setup.add_argument('--install-service',action='store_true')
    edit = sub.add_parser('edit')
    edit.add_argument('--summary',required=True)
    edit.add_argument('--changes',required=True)
    edit.add_argument('--id')
    edit.add_argument('--task')
    capture = sub.add_parser('capture')
    capture.add_argument('--summary',required=True)
    capture.add_argument('--base',default='refs/remotes/origin/main')
    capture.add_argument('paths',nargs='+')
    adopt = sub.add_parser('adopt')
    adopt.add_argument('commit')
    sub.add_parser('publish')
    status = sub.add_parser('status')
    status.add_argument('--json',action='store_true')
    status.add_argument('-s','--short',action='store_true',help=argparse.SUPPRESS)
    status.add_argument('-b','--branch',action='store_true',help=argparse.SUPPRESS)
    if argv[0] in ('pull','push'):
        if argv[0] == 'push' and argv[1:] not in ([],['origin'],['origin','main']):
            raise Failure('Managed publication only targets the configured origin main')
        argv = ['publish']
    elif argv[0] == 'fetch':
        wiki.require_setup()
        wiki.fetch()
        print('Fetched history only; LiveSync owns the live files')
        return
    elif argv[0] in ('log','show','rev-parse','ls-remote','remote','branch','ls-files','diff'):
        wiki.require_setup()
        if argv[0] == 'remote' and argv[1:] not in ([],['-v'],['get-url','origin']):
            raise Failure('Remote mutation is disabled in the managed history store')
        if argv[0] == 'branch' and any(x in argv for x in ['-d','-D','-f','-m','-M','--delete','--force']):
            raise Failure('Branch mutation is disabled; local source commits are recovery records')
        if argv[0] == 'diff':
            with tempfile.TemporaryDirectory(prefix='inspect-',dir=wiki.state) as temp:
                env = {'GIT_INDEX_FILE':str(Path(temp)/'index'),'GIT_WORK_TREE':str(wiki.wiki)}
                wiki.git('read-tree','refs/remotes/origin/main',env=env)
                print(wiki.git('diff','refs/remotes/origin/main',*argv[1:],env=env).stdout,end='')
        elif argv[0] == 'log':
            print(wiki.git('log','refs/remotes/origin/main',*argv[1:]).stdout,end='')
        else:
            print(wiki.git(*argv).stdout,end='')
        return
    elif argv[0] == 'add':
        raise Failure('Use llm-wiki-commit "summary" --changes edits.json to edit and commit atomically; shared-index staging is disabled')
    args = parser.parse_args(argv)
    if args.command == 'setup':
        result = wiki.setup(args.role,args.install_service)
    elif args.command == 'edit':
        result = wiki.edit(args.summary,json.loads(Path(args.changes).read_text()),args.id,args.task)
    elif args.command == 'capture':
        result = wiki.capture(args.summary,args.paths,args.base)
    elif args.command == 'adopt':
        result = wiki.adopt(args.commit)
    elif args.command == 'publish':
        result = wiki.publish()
    else:
        result = wiki.status()
    print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__ == '__main__':
    try:
        main()
    except (Failure,ValueError,KeyError,OSError,subprocess.SubprocessError) as error:
        print('llm-wiki: '+str(error),file=sys.stderr)
        sys.exit(2)
