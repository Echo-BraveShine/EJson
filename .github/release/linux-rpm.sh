#!/usr/bin/env bash
set -euo pipefail

if ! command -v patchelf >/dev/null; then
  echo '::error::RPM packaging requires patchelf on PATH.' >&2
  exit 1
fi

bundle_archive=$(realpath "$1")
arch=$2
output="$PWD/EJson-linux-$arch.rpm"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/SOURCES"
cp "$bundle_archive" "$staging/SOURCES/ejson.tar.gz"

rpmbuild -bb --target "$arch" --define "_topdir $staging" \
  --define "ejson_version $EXPECTED_VERSION" --define "ejson_build $EXPECTED_BUILD" \
  "$(dirname "$0")/ejson.spec"
install -m 0644 "$staging/RPMS/$arch/ejson-$EXPECTED_VERSION-$EXPECTED_BUILD.$arch.rpm" "$output"
test "$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' "$output")" \
  = "$EXPECTED_VERSION-$EXPECTED_BUILD.$arch"
rpm -qpl "$output" > "$staging/files"
grep -Fx /opt/ejson/ejson "$staging/files"
grep -Fx /usr/bin/ejson "$staging/files"
grep -Fx /usr/share/applications/dev.ekko.ejson.desktop "$staging/files"
