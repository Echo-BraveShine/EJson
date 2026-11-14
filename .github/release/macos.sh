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
if [[ "${#expected_archs[@]}" == 1 && "$(lipo -archs "$runner")" != "${expected_archs[0]}" ]]; then
  echo "::error::Expected a single ${expected_archs[0]} slice in $runner"
  exit 1
fi
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
    ditto "$app" "$staging/EJson.app"
    ln -s /Applications "$staging/Applications"
    hdiutil create -volname EJson -srcfolder "$staging" -format UDZO "$output"
    hdiutil verify "$output"
    ;;
  *)
    echo "::error::Unsupported macOS package: $output"
    exit 1
    ;;
esac
