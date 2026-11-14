import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var openFilesChannel: FlutterMethodChannel?
  private var pendingFiles: [[String: String]] = []
  private var fileReceiverReady = false

  func configureFileOpens(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "dev.ekko.ejson/open-files", binaryMessenger: messenger)
    openFilesChannel = channel
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self else { reply(nil); return }
      guard call.method == "ready" else { reply(FlutterMethodNotImplemented); return }
      self.fileReceiverReady = true
      let files = self.pendingFiles
      self.pendingFiles.removeAll()
      reply(files)
    }
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let files: [[String: String]] = urls.filter { $0.isFileURL }.map { url in
      let accessed = url.startAccessingSecurityScopedResource()
      defer { if accessed { url.stopAccessingSecurityScopedResource() } }
      var file = ["path": url.path]
      if let bookmark = try? url.bookmarkData(options: .withSecurityScope) {
        file["bookmark"] = bookmark.base64EncodedString()
      }
      return file
    }
    guard !files.isEmpty else { return }
    if fileReceiverReady {
      openFilesChannel?.invokeMethod("open", arguments: files)
    } else {
      pendingFiles.append(contentsOf: files)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
