#!/usr/bin/env python3
"""Use the owner's private signing configuration; never print or copy secrets."""
from pathlib import Path
import json, os, subprocess
root=Path(__file__).resolve().parent.parent
config=json.loads((Path.home()/'.config/evernoise/signing.json').read_text())['android']
password=Path(config['password_file']).read_text().strip()
env={**os.environ,'EVERNOISE_KEYSTORE':config['keystore'],'EVERNOISE_STORE_PASSWORD':password,'EVERNOISE_KEY_PASSWORD':password}
subprocess.run([str(root/'android/gradlew'),'-p',str(root/'android'),'assembleRelease'],env=env,check=True)
