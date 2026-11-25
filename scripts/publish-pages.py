#!/usr/bin/env python3
"""Publish only built web files and signed public F-Droid files to gh-pages."""
from pathlib import Path
import shutil, subprocess
root=Path(__file__).resolve().parent.parent
stage=root/'artifacts/pages'
remote='git@github.com:niembro64/EverNoise.git'
def run(*args,cwd=root):return subprocess.run(args,cwd=cwd,check=True,text=True)
if not (stage/'.git').exists():
    exists=subprocess.check_output(['git','ls-remote',remote,'refs/heads/gh-pages'],text=True).strip()
    if exists:run('git','clone','--single-branch','--branch','gh-pages',remote,str(stage))
    else:
        stage.mkdir(parents=True,exist_ok=True);run('git','init','-b','gh-pages',str(stage));run('git','remote','add','origin',remote,cwd=stage)
else:run('git','pull','--ff-only','origin','gh-pages',cwd=stage)
for p in stage.iterdir():
    if p.name=='.git':continue
    if p.is_dir():shutil.rmtree(p)
    else:p.unlink()
shutil.copytree(root/'web/dist',stage,dirs_exist_ok=True)
# Private config is in the parent of repo. Status logs contain local paths and
# are not needed by clients, so exclude those too.
shutil.copytree(root/'artifacts/fdroid/repo',stage/'fdroid/repo',ignore=shutil.ignore_patterns('status'),dirs_exist_ok=True)
for forbidden in ['config.yml','signing.json','check.html']:
    if any(stage.rglob(forbidden)):raise RuntimeError('Unexpected private/test file: '+forbidden)
run('git','add','-A',cwd=stage)
if subprocess.run(['git','diff','--cached','--quiet'],cwd=stage).returncode:
    revision=subprocess.check_output(['git','rev-parse','--short','HEAD'],cwd=root,text=True).strip()
    run('git','commit','-m','Publish EverNoise web and Android repository from '+revision,cwd=stage)
    run('git','push','-u','origin','gh-pages',cwd=stage)
