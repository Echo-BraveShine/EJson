#!/usr/bin/env bash
set -euo pipefail

bundle=$(realpath "$1")
arch=$2
output="$PWD/EJson-linux-$arch.AppImage"
case "$arch" in
  x86_64)
    tool_sha=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
    runtime_sha=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
    ;;
  aarch64)
    tool_sha=f0837e7448a0c1e4e650a93bb3e85802546e60654ef287576f46c71c126a9158
    runtime_sha=00cbdfcf917cc6c0ff6d3347d59e0ca1f7f45a6df1a428a0d6d8a78664d87444
    ;;
  *) exit 1 ;;
esac

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
tool="$staging/appimagetool"
runtime="$staging/runtime"
curl -fsSL --retry 3 -o "$tool" \
  "https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-$arch.AppImage"
curl -fsSL --retry 3 -o "$runtime" \
  "https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-$arch"
printf '%s  %s\n' "$tool_sha" "$tool" "$runtime_sha" "$runtime" | sha256sum --check --strict
chmod +x "$tool"

id=dev.ekko.ejson
appdir="$staging/EJson.AppDir"
mkdir "$appdir"
cp -a "$bundle"/. "$appdir/"
ln -s ejson "$appdir/AppRun"
ln -s "share/applications/$id.desktop" "$appdir/$id.desktop"
ln -s "share/icons/hicolor/256x256/apps/$id.png" "$appdir/$id.png"
ARCH="$arch" VERSION="$EXPECTED_VERSION+$EXPECTED_BUILD" APPIMAGE_EXTRACT_AND_RUN=1 \
  "$tool" --no-appstream --runtime-file "$runtime" "$appdir" "$output"

cd "$staging"
"$output" --appimage-extract >/dev/null
test -x squashfs-root/AppRun
test -f "squashfs-root/$id.png"
jq -e --arg version "$EXPECTED_VERSION" --arg build "$EXPECTED_BUILD" \
  '.version == $version and .build_number == $build' \
  squashfs-root/data/flutter_assets/version.json

# Wait for the actual window to become visible without relying on FUSE in CI.
xvfb-run -a bash -eu -s -- "$output" <<'BASH'
APPIMAGE_EXTRACT_AND_RUN=1 "$1" &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true' EXIT
timeout 30 xdotool search --sync --onlyvisible --name '^EJson$'
BASH
