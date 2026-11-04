#!/usr/bin/env bash
# Export a signed Android APK using the off-repo project keystore.
# Credentials: /home/box/secrets/prefrontalcortexgame/credentials.env
# On another machine: copy that credentials file + keystore, set KEYSTORE_* env vars,
# or point CREDENTIALS_ENV at your private credentials.env.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREDENTIALS_ENV="${CREDENTIALS_ENV:-/home/box/secrets/prefrontalcortexgame/credentials.env}"
PRESET_NAME="${PRESET_NAME:-Android}"
OUT_APK="${1:-}"

if [[ ! -f "$CREDENTIALS_ENV" ]]; then
  echo "Missing credentials: $CREDENTIALS_ENV" >&2
  echo "Create it from the private keystore backup (KEYSTORE_PATH, KEYSTORE_ALIAS, KEYSTORE_STORE_PASSWORD, KEYSTORE_KEY_PASSWORD)." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CREDENTIALS_ENV"

: "${KEYSTORE_PATH:?}"
: "${KEYSTORE_ALIAS:?}"
: "${KEYSTORE_STORE_PASSWORD:?}"
: "${KEYSTORE_KEY_PASSWORD:?}"

if [[ ! -f "$KEYSTORE_PATH" ]]; then
  echo "Keystore not found: $KEYSTORE_PATH" >&2
  exit 1
fi

cd "$ROOT"
PRESETS="$ROOT/export_presets.cfg"
BACKUP="$(mktemp)"
cp "$PRESETS" "$BACKUP"
restore_presets() { cp "$BACKUP" "$PRESETS"; rm -f "$BACKUP"; }
trap restore_presets EXIT

# Read version from presets for default output name
VERSION_NAME="$(grep -E '^version/name=' "$PRESETS" | head -1 | cut -d= -f2 | tr -d '"')"
VERSION_NAME="${VERSION_NAME:-dev}"
mkdir -p "$ROOT/build"
if [[ -z "$OUT_APK" ]]; then
  OUT_APK="$ROOT/build/PrefrontalCortexGame-${VERSION_NAME}.apk"
fi

# Point release (+ debug slot) at the project keystore so both export modes share one signing identity
python3 - "$PRESETS" "$KEYSTORE_PATH" "$KEYSTORE_ALIAS" "$KEYSTORE_STORE_PASSWORD" "$KEYSTORE_KEY_PASSWORD" "$OUT_APK" <<'PY'
import sys
from pathlib import Path
path, ks, alias, store_pw, key_pw, out_apk = sys.argv[1:7]
text = Path(path).read_text()
replacements = {
    "export_path=": f'export_path="{out_apk}"' if False else None,
}
# line-based replace for known keys under preset.0.options
lines = []
for line in text.splitlines():
    if line.startswith("export_path="):
        lines.append(f'export_path="{out_apk}"')
    elif line.startswith("keystore/debug="):
        lines.append(f'keystore/debug="{ks}"')
    elif line.startswith("keystore/debug_user="):
        lines.append(f'keystore/debug_user="{alias}"')
    elif line.startswith("keystore/debug_password="):
        lines.append(f'keystore/debug_password="{store_pw}"')
    elif line.startswith("keystore/release="):
        lines.append(f'keystore/release="{ks}"')
    elif line.startswith("keystore/release_user="):
        lines.append(f'keystore/release_user="{alias}"')
    elif line.startswith("keystore/release_password="):
        lines.append(f'keystore/release_password="{store_pw}"')
    else:
        lines.append(line)
Path(path).write_text("\n".join(lines) + "\n")
PY

export JAVA_HOME="${JAVA_HOME:-/home/box/jdk/current}"
export ANDROID_HOME="${ANDROID_HOME:-/home/box/android-sdk}"
export PATH="$JAVA_HOME/bin:${PATH:-}"

GODOT="${GODOT:-$(command -v godot || true)}"
if [[ -z "$GODOT" && -x /home/box/godot/Godot_v4.7.2-stable_linux.x86_64 ]]; then
  GODOT=/home/box/godot/Godot_v4.7.2-stable_linux.x86_64
fi
if [[ -z "$GODOT" ]]; then
  echo "godot binary not found" >&2
  exit 1
fi

echo "Exporting $PRESET_NAME -> $OUT_APK (project keystore alias=$KEYSTORE_ALIAS)"
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET_NAME" "$OUT_APK"
echo "Done: $OUT_APK"
ls -lh "$OUT_APK"
