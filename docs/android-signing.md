# Android signing

Official release APKs are published by GitHub Actions when you push a version-matching tag (for example `v1.8.0`). The workflow restores the release keystore from this repository's Actions Secrets, runs `./tools/export_android.sh`, and attaches the signed APK to a new GitHub Release. It will not overwrite assets on an already-published release.

## Cutting a release

1. Bump `config/version` in `project.godot` and both `version/name` and `version/code` in `export_presets.cfg` on `main` (same version string, no leading `v`).
2. Merge that change to `main`.
3. Push a tag that matches the version: `git tag vX.Y.Z && git push origin vX.Y.Z`.
4. The **Build and publish APK** workflow signs the APK with the same project key as earlier official builds, so users can upgrade in place.

A dry-run (signed APK artifact only, no GitHub Release) can be started from the Actions tab: **Build and publish APK** → Run workflow, leave `publish` unchecked.

## Repository Secrets

These Secrets must be set on this public repo (values never belong in git):

- `ANDROID_KEYSTORE_BASE64` — base64-encoded keystore file (`base64 -w0 the.keystore`)
- `KEYSTORE_ALIAS`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`

The workflow writes a temporary `credentials.env` and calls the existing export script. `export_presets.cfg` in git must keep every `keystore/*` field empty.

## Keystore backup

The same keystore is also backed up in the **private** repo `JeffGu98/PrefrontalCortexGame-keystore` (and on the build machine). Keep that repo private and do not delete it: GitHub Secrets cannot be read back out, so the private repo is the copy you can still restore from. Never commit `.keystore`, `credentials.env`, or passwords to this public repository.

- On the Grok Bot box, local export is still:

  ```bash
  ./tools/export_android.sh
  ```

  That script loads private credentials from the box secrets directory (or `CREDENTIALS_ENV`) and signs the APK. You can also set `KEYSTORE_PATH`, `KEYSTORE_ALIAS`, `KEYSTORE_STORE_PASSWORD`, and `KEYSTORE_KEY_PASSWORD` in the environment instead of a file.
- On any other machine: clone the private keystore repo (or use your encrypted backup), then point Godot’s Android export “Release” keystore at the file, or set `CREDENTIALS_ENV` / the `KEYSTORE_*` variables and run `tools/export_android.sh`.
- Switching signing keys requires users to uninstall the old app before installing the new one (Android signature mismatch). Keep one project key forever so upgrades stay seamless.
