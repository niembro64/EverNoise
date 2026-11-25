#!/usr/bin/env python3
"""Stage public signed indexes separately from private signing configuration."""
from pathlib import Path
import json, os, shutil, subprocess, sys
root=Path(__file__).resolve().parent.parent
stage=root/'artifacts/fdroid'
(stage/'repo').mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'distribution/metadata',stage/'metadata',dirs_exist_ok=True)
shutil.copy2(root/'android/app/build/outputs/apk/release/app-release.apk',stage/'repo/io.niemo.evernoise_1.apk')
shutil.copy2(root/'web/src/icon-192.png',stage/'repo-icon.png')
key=json.loads((Path.home()/'.config/evernoise/signing.json').read_text())['repository']
password=Path(key['password_file']).read_text().strip()
config={'repo_url':'https://niemo.io/evernoise/app/fdroid/repo','repo_name':'EverNoise','repo_description':'Official EverNoise releases from Eric Niemeyer. Free, offline, continuous noise.','repo_icon':'repo-icon.png','repo_keyalias':'evernoise','keystore':key['keystore'],'keystorepass':password,'keypass':password,'keydname':'CN=EverNoise, O=Eric Niemeyer','sdk_path':os.environ.get('ANDROID_HOME',str(Path.home()/'Library/Android/sdk')),'archive_older':0}
p=stage/'config.yml';p.write_text(json.dumps(config,indent=2)+'\n');p.chmod(0o600)
exe=root/'tools/distribution-venv/bin/fdroid'
subprocess.run([str(exe),'update','--pretty'],cwd=stage,check=True)
print('Public repository: '+str(stage/'repo'))
