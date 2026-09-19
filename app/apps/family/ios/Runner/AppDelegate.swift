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
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
