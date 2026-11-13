# EJson

[简体中文](README.md) · English

A desktop JSON editor with side-by-side source and tree editing, syntax diagnostics, and workspace restore.

[Website](https://echo-braveshine.github.io/EJson/) · [Download](https://github.com/Echo-BraveShine/EJson/releases/latest) · [Report an issue](https://github.com/Echo-BraveShine/EJson/issues) · [Buy me a coffee](https://buymeacoffee.com/1239383708p)

![EJson workbench showing the source editor and JSON tree](website/assets/workbench.png)

## Features

| Feature | What it does |
| --- | --- |
| Source editor | Syntax highlighting, line numbers, diagnostic navigation, formatting, and minifying |
| JSON tree | Expand deep nodes, scroll horizontally, focus a subtree, jump to source, rename keys, and replace values |
| Lossless formatting | Preserve duplicate keys, raw numbers, and string escapes |
| Local workspace | Multiple tabs, unsaved-change confirmation, external-change detection, and startup restore |
| Appearance | Light and dark modes, English and Simplified Chinese, and independent editor and tree styles |

Editing and parsing run locally. Checking for updates queries GitHub Releases only on demand. The support button opens Buy Me a Coffee in your browser.

## Install

Choose a package from [GitHub Releases](https://github.com/Echo-BraveShine/EJson/releases/latest).

- **macOS 12+**: Extract the ZIP and move `EJson.app` into Applications. GitHub Actions builds are not notarized by Apple.
- **Windows**: Run `EJson-Windows-x64-Setup.exe` and open EJson from the Start menu. For the portable edition, extract the ZIP and run `ejson.exe`.
- **Linux**: Extract the `.tar.gz` and run `./ejson` from the extracted directory. GTK 3 is required.

On macOS, you can also install with Homebrew.

```sh
brew tap echo-braveshine/ejson https://github.com/Echo-BraveShine/EJson.git
brew install --cask echo-braveshine/ejson/ejson
```

To upgrade, run `brew update` followed by `brew upgrade --cask echo-braveshine/ejson/ejson`.

On Windows, download `EchoBraveShine.EJson.yaml` from the release page to install with WinGet. For first-time use of local manifests, run `winget settings --enable LocalManifestFiles` in an administrator terminal.

```powershell
winget install --manifest .\EchoBraveShine.EJson.yaml
```

On x64 Ubuntu 24.04+ or Debian 13+, download the `.deb` from the release page and run the following command. To upgrade, download and install the newer package.

```sh
sudo apt install ./EJson-linux-amd64.deb
```

## Development

Install FVM and the Flutter desktop toolchain for your platform, then run:

```sh
fvm install
cd apps/ejson
fvm flutter pub get
fvm flutter run -d macos
```

Use `windows` or `linux` on the corresponding host. The app lives in [apps/ejson](apps/ejson) and the pure Dart JSON engine in [packages/ejson_core](packages/ejson_core). From the repository root, run `fvm flutter analyze --no-pub`, `fvm dart run melos run test:core`, and `fvm dart run melos run test:app`.

## CI, website, and releases

- [Desktop checks](.github/workflows/desktop.yml) runs formatting, analysis, tests, and native builds on all three platforms.
- [Website](.github/workflows/pages.yml) deploys [website](website) to GitHub Pages. For the first deployment, select GitHub Actions under Settings → Pages. Then open Actions → Website, select `main`, and click Run workflow. Later website changes pushed to `main` trigger deployment.
- [Release](.github/workflows/release.yml) builds archives for all three platforms and publishes a GitHub Release when a `vX.Y.Z` tag is pushed. To publish an existing tag, open Actions → Release, select `main`, click Run workflow, and enter the tag. The workflow builds the tagged source. The tag must match that revision's app version in `apps/ejson/pubspec.yaml` before the `+build` suffix. The app checks the latest stable release.
