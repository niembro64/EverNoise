#!/usr/bin/env python3
"""Publish the generated app into a new validated public niemo.io release."""
from pathlib import Path
import hashlib, json, shutil, subprocess
root=Path(__file__).resolve().parent.parent
stage=root/'artifacts/niemo-app'
if stage.exists():shutil.rmtree(stage)
shutil.copytree(root/'web/dist',stage)
shutil.copytree(root/'artifacts/fdroid/repo',stage/'fdroid/repo',ignore=shutil.ignore_patterns('status'))
for forbidden in ['config.yml','signing.json','check.html']:
    if any(stage.rglob(forbidden)):raise RuntimeError('Unexpected private/test file: '+forbidden)
revision=subprocess.check_output(['git','rev-parse','--short','HEAD'],cwd=root,text=True).strip()
manifest={str(p.relative_to(stage)):hashlib.sha256(p.read_bytes()).hexdigest() for p in stage.rglob('*') if p.is_file()}
remote='/tmp/evernoise-app-'+revision
subprocess.run(['rsync','-a','--delete',str(stage)+'/', 'niemo-edge:'+remote+'/'],check=True)
# The only replaced application subtree is evernoise/app. Every other public
# file is copied from the currently deployed release and verified unchanged.
script='''
from pathlib import Path
import hashlib,json,os,shutil,time
current=Path('/srv/niemo-public-current')
previous=current.resolve()
assert previous.parent==Path('/srv/niemo-public-releases')
release=previous.parent/('20261125-evernoise-app-REV-'+str(time.time_ns()))
upload=Path('UPLOAD')
expected=json.loads('MANIFEST')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert all(digest(upload/p)==h for p,h in expected.items())
shutil.copytree(previous,release)
target=release/'evernoise/app'
if target.exists():shutil.rmtree(target)
shutil.copytree(upload,target)
assert all(digest(target/p)==h for p,h in expected.items())
preserved=0
for p in previous.rglob('*'):
    if p.is_file() and not str(p.relative_to(previous)).startswith('evernoise/app/'):
        assert digest(p)==digest(release/p.relative_to(previous))
        preserved+=1
assert current.resolve()==previous, 'Another deployment changed the public root'
next_link=Path('/srv/niemo-public-next-REV')
assert not next_link.exists()
os.symlink(release,next_link)
os.replace(next_link,current)
print(json.dumps({'previous':str(previous),'release':str(release),'app_files':len(expected),'unrelated_files_verified':preserved,'url':'https://niemo.io/evernoise/app/'}))
'''.replace('REV',revision).replace('UPLOAD',remote).replace('MANIFEST',json.dumps(manifest))
r=subprocess.run(['ssh','-o','BatchMode=yes','niemo-edge','sudo -n python3 -'],input=script,text=True,capture_output=True,check=True)
(root/'artifacts/niemo-deployment.json').write_text(r.stdout)
print(r.stdout)
