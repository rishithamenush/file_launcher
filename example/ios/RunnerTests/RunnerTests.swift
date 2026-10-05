import Flutter
import XCTest
@testable import file_launcher

final class RunnerTests: XCTestCase {
  func testMissingFileReturnsWithoutPresentation() {
    let engine = FlutterEngine(name: "file-launcher-test")
    let registrar = engine.registrar(forPlugin: "file-launcher-test")!
    let plugin = FileLauncherPlugin(registrar: registrar)
    let completed = expectation(description: "Native response")
    let path = NSTemporaryDirectory() + UUID().uuidString + ".pdf"
    plugin.handle(FlutterMethodCall(methodName: "open", arguments: ["path": path])) { value in
      XCTAssertEqual((value as? [String: String])?["status"], "fileNotFound")
      completed.fulfill()
    }
    waitForExpectations(timeout: 2)
  }
}
