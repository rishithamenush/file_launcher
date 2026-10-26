import Flutter
import QuickLook
import UIKit

public final class FileLauncherPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private weak var activePresentation: UIViewController?
  private var preparing = false

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "file_launcher", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FileLauncherPlugin(registrar: registrar), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // All UIKit work and channel responses stay on the main queue.
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
    guard !preparing, activePresentation?.presentingViewController == nil else {
      result(Self.response("busy", "A presentation is already open or being prepared; try again after it closes"))
      return
    }
    if call.method == "openBytes" {
      guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data,
            let name = args["fileName"] as? String, Self.isFileName(name) else {
        result(Self.response("invalidPath", "Provide a file name without path separators"))
        return
      }
      preparing = true
      // Write off the main queue; large content must not block the UI.
      DispatchQueue.global(qos: .userInitiated).async {
        let staged = Result { try Self.stage(data, name: name) }
        DispatchQueue.main.async {
          self.preparing = false
          switch staged {
          case .success(let url): self.present(url, share: false, args: args, result: result)
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
    present(URL(fileURLWithPath: path), share: call.method == "share", args: args, result: result)
  }

  private func present(_ url: URL, share: Bool, args: [String: Any], result: @escaping FlutterResult) {
    guard let presenter = topViewController(), presenter.viewIfLoaded?.window != nil else {
      result(Self.response("noViewController", "No active screen to present on"))
      return
    }
    guard activePresentation?.presentingViewController == nil,
          !presenter.isBeingPresented, !presenter.isBeingDismissed,
          presenter.transitionCoordinator == nil else {
      result(Self.response("busy", "A presentation is already open or transitioning; try again after it closes"))
      return
    }
    let title = (args["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? url.lastPathComponent
    let controller: UIViewController
    let status: String
    if !share && QLPreviewController.canPreview(url as NSURL) {
      controller = FilePreviewController(url: url, title: title)
      status = "done"
    } else {
      let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        if let origin = Self.rect(args["origin"]) {
          // Flutter sends global logical coordinates, relative to its own view.
          let flutterView = registrar.viewController?.viewIfLoaded
          popover.sourceRect = flutterView.map { presenter.view.convert(origin, from: $0) } ?? origin
          popover.permittedArrowDirections = .any
        } else {
          popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
          popover.permittedArrowDirections = []
        }
      }
      controller = sheet
      status = "shareSheet"
    }
    // No dismissal callback or animation completion is needed to answer Dart.
    presenter.present(controller, animated: false)
    guard controller.presentingViewController != nil else {
      result(Self.response("error", "The system declined the presentation"))
      return
    }
    activePresentation = controller
    result(Self.response(status, status == "done" ? "Showing Quick Look preview" : "Showing share sheet"))
  }

  private func clearCache(result: @escaping FlutterResult) {
    guard !preparing, activePresentation?.presentingViewController == nil else {
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

  private func topViewController() -> UIViewController? {
    guard UIApplication.shared.applicationState == .active else { return nil }
    let root: UIViewController?
    // Re-read the calling engine's window on every call, including legacy apps.
    if let window = registrar.viewController?.viewIfLoaded?.window {
      if let scene = window.windowScene, scene.activationState != .foregroundActive { return nil }
      root = window.rootViewController
    } else {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
      // Do not arbitrarily choose another engine's window in a multi-window app.
      guard scenes.count <= 1 else { return nil }
      let windows = scenes.first?.windows ?? UIApplication.shared.windows
      root = windows.first(where: { $0.isKeyWindow })?.rootViewController
    }
    var top = root
    while let current = top {
      if let presented = current.presentedViewController, !presented.isBeingDismissed {
        top = presented
      } else if let nav = current as? UINavigationController, let visible = nav.visibleViewController {
        top = visible
      } else if let tabs = current as? UITabBarController, let selected = tabs.selectedViewController {
        top = selected
      } else { break }
    }
    return top
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

// Each preview owns its item, so subsequent calls cannot overwrite an open file.
private final class FilePreviewController: QLPreviewController, QLPreviewControllerDataSource {
  private let item: FilePreviewItem
  init(url: URL, title: String) {
    item = FilePreviewItem(url: url, title: title)
    super.init(nibName: nil, bundle: nil)
    dataSource = self
    modalPresentationStyle = .fullScreen
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { item }
}

private final class FilePreviewItem: NSObject, QLPreviewItem {
  let previewItemURL: URL?
  let previewItemTitle: String?
  init(url: URL, title: String) {
    previewItemURL = url
    previewItemTitle = title
  }
}
