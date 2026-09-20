import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Reminders are local notifications on iOS; this lets them show while
    // the app is open too.
    UNUserNotificationCenter.current().delegate = self
    // The family map's key, from Maps.xcconfig (gitignored). Without one the
    // Maps SDK aborts the app as soon as a map is built, so the app asks
    // first and shows the map only when there is a key.
    let key = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String ?? ""
    if !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(
        name: "family/maps",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { call, result in
        result(call.method == "hasKey" ? !key.isEmpty : FlutterMethodNotImplemented)
      }
      // A link the share extension left in the group we share with it.
      shared = FlutterMethodChannel(
        name: "family/share",
        binaryMessenger: controller.binaryMessenger
      )
      shared?.setMethodCallHandler { [weak self] call, result in
        guard call.method == "take" else { return result(FlutterMethodNotImplemented) }
        result(self?.takeSharedLink())
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private var shared: FlutterMethodChannel?

  /// The extension opens the app with its own scheme once it has written a
  /// link; the app reads it once and clears it.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "familyplanner" {
      if let link = takeSharedLink() {
        shared?.invokeMethod("shared", arguments: link)
      }
      return true
    }
    return super.application(app, open: url, options: options)
  }

  private func takeSharedLink() -> String? {
    let defaults = UserDefaults(suiteName: "group.io.github.johancarlstedt.family")
    guard let link = defaults?.string(forKey: "shared.link"), !link.isEmpty else {
      return nil
    }
    defaults?.removeObject(forKey: "shared.link")
    return link
  }
}
