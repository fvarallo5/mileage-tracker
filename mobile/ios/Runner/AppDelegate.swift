import AppIntents
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    CarBluetoothHandler.register(messenger: messenger)
    ActivityRecognitionHandler.register(messenger: messenger)
    TrekTrackVoiceBridge.register(messenger: messenger)
  }
}

/// Bridges Siri / App Shortcuts to Flutter without third-party plugins.
enum TrekTrackVoiceBridge {
  private static var channel: FlutterMethodChannel?

  static func register(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.mileagetracker/voice_commands",
      binaryMessenger: messenger
    )
  }

  static func invoke(_ method: String) async -> String {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        guard let channel else {
          continuation.resume(returning: "TrekTrack is not ready yet. Open the app and try again.")
          return
        }
        channel.invokeMethod(method, arguments: nil) { result in
          if let value = result as? String {
            continuation.resume(returning: value)
          } else if let error = result as? FlutterError {
            continuation.resume(returning: error.message ?? "Command failed")
          } else {
            continuation.resume(returning: "Done")
          }
        }
      }
    }
  }
}

enum MileageAppIntentError: Error {
  case executionFailed(String)
}

@available(iOS 16.0, *)
struct StartTripIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Trip"
  static var description = IntentDescription("Start GPS mileage tracking")
  static var isDiscoverable = true
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    let value = await TrekTrackVoiceBridge.invoke("start_trip")
    return .result(value: value)
  }
}

@available(iOS 16.0, *)
struct StopTripIntent: AppIntent {
  static var title: LocalizedStringResource = "Stop Trip"
  static var description = IntentDescription("Stop tracking and save the current trip")
  static var isDiscoverable = true
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    let value = await TrekTrackVoiceBridge.invoke("stop_trip")
    return .result(value: value)
  }
}

@available(iOS 16.0, *)
struct MileageTrackerShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartTripIntent(),
      phrases: [
        "Start trip with \(.applicationName)",
        "Start tracking with \(.applicationName)",
        "Begin trip in \(.applicationName)",
      ]
    )
    AppShortcut(
      intent: StopTripIntent(),
      phrases: [
        "Stop trip with \(.applicationName)",
        "Stop tracking with \(.applicationName)",
        "End trip in \(.applicationName)",
      ]
    )
  }
}
