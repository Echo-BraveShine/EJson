#!/usr/bin/env bash
set -euo pipefail

app=$1
output=$2
read -r -a expected_archs <<< "$3"

plist="$app/Contents/Info.plist"
name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
if [[ "$name+$build" != "$EXPECTED_VERSION+$EXPECTED_BUILD" ]]; then
  echo "::error::macOS package version is $name+$build, expected $EXPECTED_VERSION+$EXPECTED_BUILD"
  exit 1
fi

check_slices() {
  local binary=$1 archs arch
  archs=$(lipo -archs "$binary")
  for arch in "${expected_archs[@]}"; do
    if [[ " $archs " != *" $arch "* ]]; then
      echo "::error::$binary is missing $arch (found: $archs)"
      exit 1
    fi
  done
}

runner="$app/Contents/MacOS/EJson"
check_slices "$runner"
while IFS= read -r -d '' binary; do
  if [[ "$(file -b "$binary")" == *Mach-O* ]]; then
    check_slices "$binary"
  fi
done < <(find "$app/Contents/Frameworks" -type f -print0)
codesign --verify --deep --strict "$app"

case "$output" in
  *.zip)
    ditto -c -k --sequesterRsrc --keepParent "$app" "$output"
    ;;
  *.dmg)
    staging=$(mktemp -d)
    trap 'rm -rf "$staging"' EXIT
    if [[ -n "${THIN_ARCH:-}" ]]; then
      # Thinning changes Mach-O files, so restore the existing signature metadata.
      ditto --arch "$THIN_ARCH" "$app" "$staging/EJson.app"
      codesign --force --deep --sign - \
        --preserve-metadata=entitlements,requirements,flags,runtime \
        "$staging/EJson.app"
    else
      ditto "$app" "$staging/EJson.app"
    fi
    packaged="$staging/EJson.app"
    packaged_runner="$packaged/Contents/MacOS/EJson"
    check_slices "$packaged_runner"
    if [[ -n "${THIN_ARCH:-}" && "$(lipo -archs "$packaged_runner")" != "$THIN_ARCH" ]]; then
      echo "::error::Expected a single $THIN_ARCH slice in $packaged_runner"
      exit 1
    fi
    while IFS= read -r -d '' binary; do
      if [[ "$(file -b "$binary")" == *Mach-O* ]]; then
        check_slices "$binary"
      fi
    done < <(find "$packaged/Contents/Frameworks" -type f -print0)
    codesign --verify --deep --strict "$packaged"
    ln -s /Applications "$staging/Applications"
    hdiutil create -volname EJson -srcfolder "$staging" -format UDZO "$output"
    hdiutil verify "$output"
    ;;
  *)
    echo "::error::Unsupported macOS package: $output"
    exit 1
    ;;
esac
