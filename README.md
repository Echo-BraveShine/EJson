# EJson

简体中文 · [English](README.en.md)

在桌面上编辑 JSON。源码和树形结构同屏，支持双向编辑、查找替换、JSONPath 查询、数组工具和工作区恢复。

[官方网站](https://echo-braveshine.github.io/EJson/) · [下载](https://github.com/Echo-BraveShine/EJson/releases/latest) · [问题反馈](https://github.com/Echo-BraveShine/EJson/issues) · [请我喝杯咖啡](https://buymeacoffee.com/1239383708p)

![EJson 工作台，左侧是源码，右侧是 JSON 树](website/assets/workbench.png)

## 功能

| 功能 | 说明 |
| --- | --- |
| 源码编辑 | 语法高亮、行号、校验、错误跳转、撤销和重做 |
| JSON 树 | 展开深层节点、横向滚动、聚焦子树、定位源码、重命名键、替换值和提取子树到新标签页 |
| 查找与替换 | 在源码、键或值中查找，支持区分大小写、正则表达式、捕获组替换和全部替换 |
| 字符串转换 | 将内容转义为 JSON 字符串，或将 JSON 字符串反转义为原始内容 |
| 无损格式化 | 格式化和压缩保留重复键、数字原文和字符串转义，可设置缩进和换行符 |
| JSONPath 查询 | 按路径定位节点，支持通配符、标量条件筛选、收藏查询及提取查询结果到新标签页 |
| 数组工具 | 表格查看、筛选、排序、复制单元格和导出 CSV，支持数组项上移、下移、复制及按值或字段排序 |
| 比较与统计 | 比较两份文档，查看字节数、节点数、最大深度和最长数组 |
| 本地工作区 | 多标签、从系统文件管理器打开 JSON、多文件拖入打开、未保存确认、外部文件修改检测和启动恢复 |
| 最近文件 | 保留最近打开或保存的 20 个文件，支持按名称或路径搜索、移除记录和清空列表 |
| 命令面板 | 使用中英文关键词搜索命令，支持方向键选择、回车执行和 Escape 关闭 |
| 阅读与外观 | 选择本机字体、字号和行距，实时预览；支持浅色、深色、中英文及独立的源码高亮与树样式 |

编辑和解析在本机完成。「检查版本更新」仅在主动点击后查询 GitHub Releases；「请我喝杯咖啡」在浏览器打开赞助页面。

## 快捷入口

| 操作 | macOS | Windows / Linux |
| --- | --- | --- |
| 打开命令面板 | `Cmd+Shift+P` | `Ctrl+Shift+P` |
| 打开最近文件 | `Cmd+P` | `Ctrl+P` |

也可以从工具栏打开命令面板和最近文件。将多个本地文件拖入工作台即可逐个打开，重复打开同一文件时会切换到已有标签页。临时拖入副本会作为新文档打开。

## 安装

从 [GitHub Releases](https://github.com/Echo-BraveShine/EJson/releases/latest) 选择对应平台的下载包。

- **macOS 12+**：Apple Silicon（M 系列）选择 `EJson-macos-arm64.dmg`，Intel Mac 选择 `EJson-macos-x86_64.dmg`。打开 DMG，将 EJson 拖入「应用程序」。通用 ZIP 和 Homebrew 构建也支持两种架构，可在 M 系列上原生运行。GitHub Actions 构建未经过 Apple 公证。
- **Windows x64**：双击 `EJson-Windows-x64-Setup.exe` 为当前用户安装，或用 `EJson-Windows-x64.msi` 为整台电脑安装。MSI 需要管理员权限。从一种安装方式切换到另一种前，先卸载旧安装。便携版可解压 ZIP 后运行 `ejson.exe`。
- **Linux**：按架构选择 `EJson-linux-x86_64.AppImage` 或 `EJson-linux-aarch64.AppImage`，赋予执行权限后双击或在终端运行，无需管理员权限。Fedora 或兼容的 RPM 系统也可用 `sudo dnf install ./EJson-linux-x86_64.rpm`（ARM64 选择 `aarch64`）。这些构建需要 glibc 2.39 或更新版本、GTK 3 和 OpenGL 运行库。

```sh
chmod +x EJson-linux-x86_64.AppImage
./EJson-linux-x86_64.AppImage
# 系统没有 FUSE 时，从终端启动
./EJson-linux-x86_64.AppImage --appimage-extract-and-run
```

macOS 也可以使用 Homebrew 安装。

```sh
brew tap echo-braveshine/ejson https://github.com/Echo-BraveShine/EJson.git
brew install --cask echo-braveshine/ejson/ejson
```

升级时先运行 `brew update`，再运行 `brew upgrade --cask echo-braveshine/ejson/ejson`。

Windows 可在发布页下载 `EchoBraveShine.EJson.yaml` 后使用 WinGet 安装。首次使用本地清单时，需在管理员终端运行 `winget settings --enable LocalManifestFiles`。

```powershell
winget install --manifest .\EchoBraveShine.EJson.yaml
```

Ubuntu 24.04+ 或 Debian 13+ 用户可运行 `dpkg --print-architecture`，然后从发布页下载对应架构的 `.deb`。升级时下载新版包并重复安装。

```sh
# amd64
sudo apt install ./EJson-linux-amd64.deb
# arm64（例如 Apple 芯片 Mac 上的 ARM Linux 虚拟机）
sudo apt install ./EJson-linux-arm64.deb
```

安装后可在 `.json` 文件的「打开方式」中选择 EJson。将 EJson 设为该文件类型的默认应用后，即可双击打开。

## 本地开发

安装 FVM 和目标平台的 Flutter 桌面工具链，然后运行：

```sh
fvm install
cd apps/ejson
fvm flutter pub get
fvm flutter run -d macos
```

在对应平台上可将设备改为 `windows` 或 `linux`。应用位于 [apps/ejson](apps/ejson)，纯 Dart JSON 核心位于 [packages/ejson_core](packages/ejson_core)。从仓库根目录运行 `fvm flutter analyze --no-pub`、`fvm dart run melos run test:core` 和 `fvm dart run melos run test:app`。

## CI、官网与发版

- [Desktop checks](.github/workflows/desktop.yml) 在分支推送和 Pull Request 时运行三平台检查。发布标签触发 Release。
- [Website](.github/workflows/pages.yml) 将 [website](website) 部署到 GitHub Pages。首次部署时，在仓库「Settings → Pages」将来源设为「GitHub Actions」，然后到「Actions → Website」选择 `main` 并点击「Run workflow」。之后推送到 `main` 的网站改动会触发部署。
- [Release](.github/workflows/release.yml) 在推送 `vX.Y.Z` 标签时构建安装包和便携包并创建 GitHub Release。已有标签可在「Actions → Release」选择 `main`，点击「Run workflow」并填写标签来补发，也可勾选 `build_only` 只构建并检查安装包。标签须与对应源码的 `apps/ejson/pubspec.yaml` 版本一致，忽略 `+build` 部分。应用内检查更新读取最新正式 Release。
