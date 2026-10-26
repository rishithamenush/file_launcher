import Cocoa
import FlutterMacOS

public final class FileLauncherPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private var preparing = false

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "file_launcher", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(FileLauncherPlugin(registrar: registrar), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // All AppKit work and channel responses stay on the main queue.
    switch call.method {
    case "open", "share", "openBytes":
      DispatchQueue.main.async { self.launch(call, result: result) }
    case "clearCache":
      DispatchQueue.main.async { self.clearCache(result: result) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func launch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "openBytes" {
      guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data,
            let name = args["fileName"] as? String, Self.isFileName(name) else {
        result(Self.response("invalidPath", "Provide a file name without path separators"))
        return
      }
      guard !preparing else {
        result(Self.response("busy", "Another file is being prepared"))
        return
      }
      preparing = true
      // Write off the main queue; large content must not block the UI.
      DispatchQueue.global(qos: .userInitiated).async {
        let staged = Result { try Self.stage(data, name: name) }
        DispatchQueue.main.async {
          self.preparing = false
          switch staged {
          case .success(let url): result(self.present(url, share: false, args: args))
          case .failure(let error): result(Self.response("error", "Could not prepare file: \(error.localizedDescription)"))
          }
        }
      }
      return
    }
    guard let path = args["path"] as? String,
          path.hasPrefix("/"), !path.utf8.contains(0) else {
      result(Self.response("invalidPath", "Provide an absolute local file path"))
      return
    }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
      result(Self.response("fileNotFound", "No regular file at: \(path)"))
      return
    }
    guard FileManager.default.isReadableFile(atPath: path) else {
      result(Self.response("fileNotReadable", "File is not readable"))
      return
    }
    result(present(URL(fileURLWithPath: path), share: call.method == "share", args: args))
  }

  /// Opens the default app, falling back to the share picker when none is registered.
  private func present(_ url: URL, share: Bool, args: [String: Any]) -> [String: String] {
    if !share && NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
      if NSWorkspace.shared.open(url) {
        return Self.response("done", "Default app launch accepted")
      }
    }
    guard let view = registrar.view, view.window != nil else {
      return Self.response(share ? "noViewController" : "noAppToOpen",
                           share ? "No window to present the share picker in" : "No app can open this file")
    }
    var anchor = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
    if let origin = Self.rect(args["origin"]) {
      // Flutter uses a top-left origin; convert for unflipped views.
      anchor = origin
      if !view.isFlipped { anchor.origin.y = view.bounds.height - origin.maxY }
    }
    // The picker runs a menu-tracking loop, so reply before showing it.
    DispatchQueue.main.async {
      NSSharingServicePicker(items: [url]).show(relativeTo: anchor, of: view, preferredEdge: .minY)
    }
    return Self.response("shareSheet", "Showing share picker")
  }

  private func clearCache(result: @escaping FlutterResult) {
    guard !preparing else {
      result(false)
      return
    }
    do {
      if FileManager.default.fileExists(atPath: Self.cacheRoot.path) {
        try FileManager.default.removeItem(at: Self.cacheRoot)
      }
      result(true)
    } catch {
      result(false)
    }
  }

  private static var cacheRoot: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("file_launcher", isDirectory: true)
  }

  /// Writes bytes to a unique directory and removes copies older than seven days.
  private static func stage(_ data: Data, name: String) throws -> URL {
    let manager = FileManager.default
    let expiry = Date().addingTimeInterval(-7 * 24 * 60 * 60)
    let entries = (try? manager.contentsOfDirectory(at: cacheRoot, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    for entry in entries {
      let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      if let modified = modified, modified < expiry { try? manager.removeItem(at: entry) }
    }
    let directory = cacheRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(name)
    try data.write(to: url, options: .atomic)
    return url
  }

  private static func isFileName(_ name: String) -> Bool {
    !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") && !name.utf8.contains(0)
  }

  private static func rect(_ value: Any?) -> CGRect? {
    guard let map = value as? [String: Any],
          let x = (map["x"] as? NSNumber)?.doubleValue, let y = (map["y"] as? NSNumber)?.doubleValue,
          let width = (map["width"] as? NSNumber)?.doubleValue, let height = (map["height"] as? NSNumber)?.doubleValue,
          [x, y, width, height].allSatisfy({ $0.isFinite }), width >= 0, height >= 0 else { return nil }
    return CGRect(x: x, y: y, width: width, height: height)
  }

  private static func response(_ status: String, _ message: String) -> [String: String] {
    ["status": status, "message": message]
  }
}
