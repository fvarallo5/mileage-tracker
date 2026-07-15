import AppIntents
import Flutter
import UIKit
import flutter_app_intents

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

  func perform() async throws -> some IntentResult & ReturnsValue<String> & OpensIntent {
    let plugin = FlutterAppIntentsPlugin.shared
    let result = await plugin.handleIntentInvocation(
      identifier: "start_trip",
      parameters: [:]
    )

    if let success = result["success"] as? Bool, success {
      let value = result["value"] as? String ?? "Started GPS trip tracking"
      return .result(value: value)
    }

    let errorMessage = result["error"] as? String ?? "Failed to start trip"
    throw MileageAppIntentError.executionFailed(errorMessage)
  }
}

@available(iOS 16.0, *)
struct StopTripIntent: AppIntent {
  static var title: LocalizedStringResource = "Stop Trip"
  static var description = IntentDescription("Stop tracking and save the current trip")
  static var isDiscoverable = true
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult & ReturnsValue<String> & OpensIntent {
    let plugin = FlutterAppIntentsPlugin.shared
    let result = await plugin.handleIntentInvocation(
      identifier: "stop_trip",
      parameters: [:]
    )

    if let success = result["success"] as? Bool, success {
      let value = result["value"] as? String ?? "Trip saved"
      return .result(value: value)
    }

    let errorMessage = result["error"] as? String ?? "Failed to stop trip"
    throw MileageAppIntentError.executionFailed(errorMessage)
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