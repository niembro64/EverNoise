# Release operations

## Keys

Android APK updates must keep the same signing key. The F-Droid repository has a
separate signing key for its indexes. On the publisher's Mac, both live outside
Git under `~/.config/evernoise/`, with directory mode 0700 and files mode 0600.
`signing.json` names their keystore and password-file paths. Back up this directory
securely; losing a key breaks its update trust chain. Never put it in a release,
web build, GitHub secret without a deliberate decision, or repository commit.

The build accepts `EVERNOISE_KEYSTORE`, `EVERNOISE_STORE_PASSWORD`, and
`EVERNOISE_KEY_PASSWORD`; alias `evernoise`. For the existing private local setup:

```sh
export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
export ANDROID_HOME="$HOME/Library/Android/sdk"
python3 scripts/build-android-release.py
```

Verify with SDK `apksigner verify --verbose --print-certs` and `zipalign -c -P 16
-v 4`. Keep the artifact hash and source commit in release evidence. Increment
`versionCode` for every distributed Android update; versionName is user-facing.

## F-Droid-compatible repository

This is an official publisher-operated EverNoise repository that users add to
F-Droid. It is **not** an accepted listing in the central f-droid.org catalog.
See [F-Droid's own-repository documentation](https://f-droid.org/en/docs/Setup_an_F-Droid_App_Repo/).

```sh
python3 -m venv tools/distribution-venv
tools/distribution-venv/bin/pip install fdroidserver==2.4.6
python3 scripts/build-fdroid.py
```

The tool reads public metadata from `distribution/metadata/` and signed APKs, then
writes a private staging config plus public output under `artifacts/fdroid/`.
**Publish only `artifacts/fdroid/repo/`, never the staging parent or config.yml.**
The publisher's identity and signing fingerprint appear on the Android install
page. Repository and APK signatures are separate and both are verified.

For a new release update the metadata version, script APK filename, web download
links, and release notes. Keep prior signed packages if you want rollback entries.
Central F-Droid inclusion requires its separate submission/review process and
policy checks; MIT licensing alone does not guarantee acceptance. App development
used AI assistance and that is disclosed rather than hidden from any catalog.

## Web and GitHub Pages

Build WASM, run tests, and `node web/scripts/build.mjs`. The resulting `web/dist/`
is a static site; no server APIs are required. The production service worker
pre-caches versioned assets, then waits for older app tabs to close before updating,
so a deployment does not force-reload active audio. Localhost does not register it.

The `gh-pages` branch contains deployable web files plus `fdroid/repo/`, with no
build tools, private configuration, or test harness. GitHub Pages serves that
branch's root. The source `main` branch retains buildable code and full history.
Publishing a Pages commit and a GitHub Release are distinct operations; check the
live site and downloaded APK hash after both complete.

## Apple

Use `apple/project.yml` and existing Apple release records. This migration changes
source paths and adds portable platform guards; it does not change the Apple app's
version or require resubmitting its current App Store release. Re-run XcodeGen
from `apple/` after project edits. Root Swift package tests use `swift test`.
