import AppIntents
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
    // What Siri was asked to add or log while the app was closed: kept in
    // the group, handed over when Dart asks, then cleared.
    FlutterMethodChannel(name: "family/voice", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "take" else { return result(FlutterMethodNotImplemented) }
        result(VoiceQueue.takeAll())
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


/// What was said to Siri, waiting for the app: the intents run without
/// the app's Dart side, so they only write it down here, in the group the
/// app shares with its extensions, and the app does it when it next runs.
enum VoiceQueue {
  static let group = "group.io.github.johancarlstedt.family"

  static func push(_ key: String, _ value: String) {
    let defaults = UserDefaults(suiteName: group)
    var list = defaults?.stringArray(forKey: key) ?? []
    list.append(value)
    defaults?.set(list, forKey: key)
  }

  static func takeAll() -> [String: [String]] {
    let defaults = UserDefaults(suiteName: group)
    var out: [String: [String]] = [:]
    for key in ["voice.shopping", "voice.activity"] {
      out[key] = defaults?.stringArray(forKey: key) ?? []
      defaults?.removeObject(forKey: key)
    }
    return out
  }

  /// Swedish if the phone is, English otherwise: what Siri says back.
  static var swedish: Bool {
    Locale.preferredLanguages.first?.hasPrefix("sv") ?? false
  }
}

@available(iOS 16.0, *)
struct AddToShoppingList: AppIntent {
  static var title: LocalizedStringResource = "Add to the shopping list"
  static var description = IntentDescription("Puts something on the family's shopping list.")

  @Parameter(title: "What", requestValueDialog: "What should go on the list?")
  var item: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    VoiceQueue.push("voice.shopping", item)
    return .result(dialog: VoiceQueue.swedish
      ? "\(item) står på inköpslistan."
      : "\(item) is on the shopping list.")
  }
}

@available(iOS 16.0, *)
struct LogActivity: AppIntent {
  static var title: LocalizedStringResource = "Log activity"
  static var description = IntentDescription("Logs time spent being active.")

  @Parameter(title: "What did you do", requestValueDialog: "What did you do?")
  var activity: String

  @Parameter(title: "Minutes", default: 30)
  var minutes: Int

  func perform() async throws -> some IntentResult & ProvidesDialog {
    VoiceQueue.push("voice.activity", "\(activity) · \(minutes) min")
    return .result(dialog: VoiceQueue.swedish
      ? "Bra jobbat! Jag har loggat \(activity), \(minutes) minuter."
      : "Well done! Logged \(activity), \(minutes) minutes.")
  }
}

@available(iOS 16.0, *)
struct WhatsOnToday: AppIntent {
  static var title: LocalizedStringResource = "What's on today"
  static var description = IntentDescription("Reads out today's plan, as the widget shows it.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    // The same words the Today widget shows, which the app keeps current.
    let defaults = UserDefaults(suiteName: VoiceQueue.group)
    let title = defaults?.string(forKey: "widget.title") ?? ""
    let body = defaults?.string(forKey: "widget.body") ?? ""
    let said = [title, body].filter { !$0.isEmpty }.joined(separator: ". ")
    return .result(dialog: IntentDialog(stringLiteral: said.isEmpty
      ? (VoiceQueue.swedish ? "Öppna appen en gång så vet jag." : "Open the app once and I'll know.")
      : said))
  }
}

@available(iOS 16.0, *)
struct FamilyShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddToShoppingList(),
      phrases: [
        "Add to the shopping list in \(.applicationName)",
        "Lägg till i inköpslistan i \(.applicationName)",
        "\(.applicationName) inköpslista",
      ],
      shortTitle: "Shopping list",
      systemImageName: "cart"
    )
    AppShortcut(
      intent: LogActivity(),
      phrases: [
        "Log activity in \(.applicationName)",
        "Logga aktivitet i \(.applicationName)",
      ],
      shortTitle: "Log activity",
      systemImageName: "figure.run"
    )
    AppShortcut(
      intent: WhatsOnToday(),
      phrases: [
        "What's on today in \(.applicationName)",
        "Vad händer idag i \(.applicationName)",
      ],
      shortTitle: "Today",
      systemImageName: "calendar"
    )
  }
}
