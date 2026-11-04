# Android signing

Release APKs are signed with a **project keystore kept off this repository** (not the Android debug key).

- Keystore file, alias, and passwords live only on the build machine / encrypted backup — never in git.
- `export_presets.cfg` in this repo intentionally leaves `keystore/*` fields empty.
- On the Grok Bot box, export with:

  ```bash
  ./tools/export_android.sh
  ```

  That script loads private credentials from the box secrets directory and signs the APK.
- On any other machine: use the same keystore backup (file + alias + passwords). Point Godot’s Android export “Release” keystore at that file, or set `CREDENTIALS_ENV` to a local credentials file and run `tools/export_android.sh`.
- Switching signing keys requires users to uninstall the old app before installing the new one (Android signature mismatch). Keep one project key forever so upgrades stay seamless.
