import CoreMotion
import Flutter
import UIKit

/// Core Motion activity updates — optional gate so auto-detect sleeps until automotive.
final class ActivityRecognitionHandler: NSObject, FlutterStreamHandler {
  static let methodChannelName = "com.mileagetracker/activity_recognition"
  static let eventChannelName = "com.mileagetracker/activity_recognition_events"

  private let manager = CMMotionActivityManager()
  private var eventSink: FlutterEventSink?
  private var lastType = "unknown"
  private var lastConfidence = 0
  private var inVehicle = false
  private var hasPermission = true

  static func register(messenger: FlutterBinaryMessenger) {
    let handler = ActivityRecognitionHandler()
    // Retain via associated storage on the messenger's channel handlers.
    FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getState":
          result(handler.currentState())
        case "isAvailable":
          result(CMMotionActivityManager.isActivityAvailable())
        case "start":
          handler.startUpdates()
          result(handler.currentState())
        case "stop":
          handler.stopUpdates()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
      .setStreamHandler(handler)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    startUpdates()
    events(currentState())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopUpdates()
    eventSink = nil
    return nil
  }

  private func startUpdates() {
    guard CMMotionActivityManager.isActivityAvailable() else {
      lastType = "unavailable"
      inVehicle = false
      emit()
      return
    }

    manager.startActivityUpdates(to: .main) { [weak self] activity in
      guard let self, let activity else { return }
      self.apply(activity)
      self.emit()
    }
  }

  private func stopUpdates() {
    manager.stopActivityUpdates()
  }

  private func apply(_ activity: CMMotionActivity) {
    // Prefer automotive, then cycling, then walking/running/stationary.
    if activity.automotive {
      lastType = "in_vehicle"
      inVehicle = true
    } else if activity.cycling {
      lastType = "on_bicycle"
      inVehicle = true
    } else if activity.running {
      lastType = "running"
      inVehicle = false
    } else if activity.walking {
      lastType = "walking"
      inVehicle = false
    } else if activity.stationary {
      lastType = "still"
      inVehicle = false
    } else {
      lastType = "unknown"
      // Keep previous inVehicle on unknown flicker — handled below for confidence.
      if activity.confidence == .low {
        // Don't flip to vehicle on low-confidence unknown.
      } else {
        inVehicle = false
      }
    }

    switch activity.confidence {
    case .low:
      lastConfidence = 25
    case .medium:
      lastConfidence = 55
    case .high:
      lastConfidence = 85
    @unknown default:
      lastConfidence = 40
    }

    // Require at least medium confidence for vehicle gate.
    if inVehicle && activity.confidence == .low {
      inVehicle = false
    }
  }

  private func emit() {
    eventSink?(currentState())
  }

  private func currentState() -> [String: Any?] {
    [
      "available": CMMotionActivityManager.isActivityAvailable(),
      "inVehicle": inVehicle,
      "activity": lastType,
      "confidence": lastConfidence,
      "permission": hasPermission,
    ]
  }
}
