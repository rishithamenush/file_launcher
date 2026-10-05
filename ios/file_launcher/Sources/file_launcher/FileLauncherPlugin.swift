import Flutter
import QuickLook
import UIKit

public final class FileLauncherPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private weak var activePresentation: UIViewController?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "file_launcher", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FileLauncherPlugin(registrar: registrar), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "open" else {
      result(FlutterMethodNotImplemented)
      return
    }
    // All UIKit work and channel responses stay on the main queue.
    DispatchQueue.main.async { self.open(call, result: result) }
  }

  private func open(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let path = args?["path"] as? String,
          path.hasPrefix("/"), !path.utf8.contains(0) else {
      result(Self.response("error", "Provide an absolute local file path"))
      return
    }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
      result(Self.response("fileNotFound", "No regular file at: \(path)"))
      return
    }
    guard FileManager.default.isReadableFile(atPath: path) else {
      result(Self.response("error", "File is not readable"))
      return
    }
    guard let presenter = topViewController(), presenter.viewIfLoaded?.window != nil else {
      result(Self.response("noViewController", "No active screen to present on"))
      return
    }
    guard activePresentation?.presentingViewController == nil,
          !presenter.isBeingPresented, !presenter.isBeingDismissed,
          presenter.transitionCoordinator == nil else {
      result(Self.response("error", "A presentation is already open or transitioning; try again after it closes"))
      return
    }
    let url = URL(fileURLWithPath: path)
    let title = (args?["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? url.lastPathComponent
    let controller: UIViewController
    let status: String
    if QLPreviewController.canPreview(url as NSURL) {
      controller = FilePreviewController(url: url, title: title)
      status = "done"
    } else {
      let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      if let popover = share.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
      controller = share
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
