import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var scopedFiles: [String: URL] = [:]

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let files = FlutterMethodChannel(
      name: "dev.ekko.ejson/files",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    files.setMethodCallHandler { [weak self] call, reply in
      guard let self else {
        reply(nil)
        return
      }
      switch call.method {
      case "atomicWrite":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String,
              let bytes = args["bytes"] as? FlutterStandardTypedData else {
          reply(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try bytes.data.write(to: URL(fileURLWithPath: path), options: .atomic)
            DispatchQueue.main.async { reply(nil) }
          } catch {
            DispatchQueue.main.async {
              reply(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "createBookmark":
        guard let path = call.arguments as? String else { reply(nil); return }
        let url = URL(fileURLWithPath: path)
        let data = try? url.bookmarkData(options: .withSecurityScope)
        reply(data?.base64EncodedString())
      case "accessBookmark":
        guard let args = call.arguments as? [String: String],
              let path = args["path"],
              let bookmark = args["bookmark"],
              let data = Data(base64Encoded: bookmark) else {
          reply(false)
          return
        }
        var stale = false
        if let url = try? URL(
          resolvingBookmarkData: data,
          options: [.withSecurityScope, .withoutUI, .withoutMounting],
          bookmarkDataIsStale: &stale
        ), url.path == path, url.startAccessingSecurityScopedResource() {
          self.scopedFiles.updateValue(url, forKey: path)?.stopAccessingSecurityScopedResource()
          reply(true)
        } else {
          reply(false)
        }
      case "releaseBookmark":
        if let path = call.arguments as? String {
          self.scopedFiles.removeValue(forKey: path)?.stopAccessingSecurityScopedResource()
        }
        reply(nil)
      default:
        reply(FlutterMethodNotImplemented)
      }
    }

    let appearance = FlutterMethodChannel(
      name: "dev.ekko.ejson/appearance",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    appearance.setMethodCallHandler { [weak self, weak flutterViewController] call, reply in
      guard let self else {
        reply(nil)
        return
      }
      switch call.method {
      case "setMenuLanguage":
        if let language = call.arguments as? String { self.updateMenuLanguage(language) }
        reply(nil)
      case "setDarkAppearance":
        if let dark = call.arguments as? Bool {
          self.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
          let asset = dark ? "assets/branding/logo_dark.png" : "assets/branding/logo_light.png"
          if let key = flutterViewController?.lookupKey(forAsset: asset) {
            let url = Bundle.main.bundleURL.appendingPathComponent(key)
            if let icon = NSImage(contentsOf: url) {
              NSApp.applicationIconImage = icon
            }
          }
        }
        reply(nil)
      default:
        reply(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private var originalMenuTitles: [ObjectIdentifier: String] = [:]

  private func updateMenuLanguage(_ language: String) {
    let chinese = [
      "About EJson": "关于 EJson",
      "Preferences…": "设置…",
      "Services": "服务",
      "Hide EJson": "隐藏 EJson",
      "Hide Others": "隐藏其他应用",
      "Show All": "全部显示",
      "Quit EJson": "退出 EJson",
      "Edit": "编辑",
      "Undo": "撤销",
      "Redo": "重做",
      "Cut": "剪切",
      "Copy": "拷贝",
      "Paste": "粘贴",
      "Paste and Match Style": "粘贴并匹配样式",
      "Delete": "删除",
      "Select All": "全选",
      "Find": "查找",
      "Find…": "查找…",
      "Find and Replace…": "查找并替换…",
      "Find Next": "查找下一个",
      "Find Previous": "查找上一个",
      "Use Selection for Find": "使用所选内容查找",
      "Jump to Selection": "跳到所选内容",
      "Spelling and Grammar": "拼写和语法",
      "Show Spelling and Grammar": "显示拼写和语法",
      "Check Document Now": "立即检查文稿",
      "Check Spelling While Typing": "键入时检查拼写",
      "Check Grammar With Spelling": "同时检查语法和拼写",
      "Correct Spelling Automatically": "自动纠正拼写",
      "Substitutions": "替换",
      "Show Substitutions": "显示替换",
      "Smart Copy/Paste": "智能拷贝与粘贴",
      "Smart Quotes": "智能引号",
      "Smart Dashes": "智能破折号",
      "Smart Links": "智能链接",
      "Data Detectors": "数据检测器",
      "Text Replacement": "文本替换",
      "Transformations": "转换",
      "Make Upper Case": "转为大写",
      "Make Lower Case": "转为小写",
      "Capitalize": "首字母大写",
      "Speech": "朗读",
      "Start Speaking": "开始朗读",
      "Stop Speaking": "停止朗读",
      "View": "显示",
      "Enter Full Screen": "进入全屏幕",
      "Window": "窗口",
      "Minimize": "最小化",
      "Zoom": "缩放",
      "Bring All to Front": "全部置于最前",
      "Help": "帮助",
    ]
    func update(_ menu: NSMenu) {
      for item in menu.items where !item.isSeparatorItem {
        let id = ObjectIdentifier(item)
        let original = originalMenuTitles[id] ?? item.title
        let key = original.replacingOccurrences(of: "APP_NAME", with: "EJson")
        if let translated = chinese[key] {
          originalMenuTitles[id] = original
          let title = language == "zh" ? translated : key
          item.title = title
          item.submenu?.title = title
        }
        if let submenu = item.submenu, key != "Services" {
          update(submenu)
        }
      }
    }
    if let menu = NSApp.mainMenu {
      update(menu)
    }
  }

}
