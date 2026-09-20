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
    mapsKey = key
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The engine is made here, not on the window: this is where the app's
    // own channels can reach Dart.
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "FamilyPlanner")?.messenger()
    else {
      return NSLog("Family Planner: no messenger, channels unavailable")
    }
    let key = mapsKey
    FlutterMethodChannel(name: "family/maps", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        result(call.method == "hasKey" ? !key.isEmpty : FlutterMethodNotImplemented)
      }
    // A link the share extension left in the group we share with it.
    shared = FlutterMethodChannel(name: "family/share", binaryMessenger: messenger)
    shared?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "take" else { return result(FlutterMethodNotImplemented) }
      result(self?.takeSharedLink())
    }
  }

  /// The Google Maps key, read at launch and answered over the channel.
  private var mapsKey = ""

  private var shared: FlutterMethodChannel?

  /// The extension opens the app with its own scheme once it has written a
  /// link; the app reads it once and clears it.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "familyplanner" {
      // Only a nudge: the link stays in the group until Dart asks for it,
      // so one that arrives before the app is listening isn't lost.
      shared?.invokeMethod("shared", arguments: nil)
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
