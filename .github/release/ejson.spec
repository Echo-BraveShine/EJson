Name: ejson
Version: %{ejson_version}
Release: %{ejson_build}
Summary: Desktop JSON editor with a synchronized tree view
License: LicenseRef-EJson
URL: https://github.com/Echo-BraveShine/EJson
Source0: ejson.tar.gz
# The packaging script checks for patchelf on PATH. Ubuntu CI installs it via
# APT, so rpmbuild cannot resolve it through the RPM database.

# The archive contains Flutter's existing release binaries.
%global debug_package %{nil}
%global __brp_strip %{nil}
%global __brp_strip_comment_note %{nil}
%global __brp_strip_static_archive %{nil}

Requires: libgtk-3.so.0()(64bit)
Requires: libGL.so.1()(64bit)

%description
EJson is an offline desktop JSON workspace with a source editor and tree view.

%install
mkdir -p %{buildroot}/opt/ejson %{buildroot}/usr/bin
tar -xzf %{SOURCE0} -C %{buildroot}/opt/ejson
# Plugins are installed beside the Flutter engine. Replace the build path with
# a path relative to each plugin so the same package works after relocation.
for plugin in %{buildroot}/opt/ejson/lib/*_plugin.so; do
  [ -f "$plugin" ] || continue
  patchelf --set-rpath '$ORIGIN' "$plugin"
done
mv %{buildroot}/opt/ejson/share %{buildroot}/usr/share
ln -s ../../opt/ejson/ejson %{buildroot}/usr/bin/ejson

%files
/opt/ejson
/usr/bin/ejson
/usr/share/applications/dev.ekko.ejson.desktop
/usr/share/icons/hicolor/256x256/apps/dev.ekko.ejson.png
