import AVFoundation
import Flutter
import UIKit

/// Detects car / Bluetooth audio routes so auto-detect can sleep until the car connects.
final class CarBluetoothHandler: NSObject, FlutterStreamHandler {
  static let methodChannelName = "com.mileagetracker/car_bluetooth"
  static let eventChannelName = "com.mileagetracker/car_bluetooth_events"

  private var eventSink: FlutterEventSink?
  private var observing = false

  static func register(messenger: FlutterBinaryMessenger) {
    let handler = CarBluetoothHandler()
    FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getState":
          result(handler.currentState())
        case "isAvailable":
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
      .setStreamHandler(handler)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    startObserving()
    events(currentState())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    eventSink = nil
    return nil
  }

  private func startObserving() {
    guard !observing else { return }
    observing = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(routeChanged),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
    try? session.setActive(true, options: .notifyOthersOnDeactivation)
  }

  private func stopObserving() {
    guard observing else { return }
    observing = false
    NotificationCenter.default.removeObserver(self)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  @objc private func routeChanged(_ notification: Notification) {
    eventSink?(currentState())
  }

  private func currentState() -> [String: Any?] {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    let vehiclePorts: Set<AVAudioSession.Port> = [
      .carAudio,
      .bluetoothA2DP,
      .bluetoothHFP,
    ]
    let car = outputs.first(where: { $0.portType == .carAudio })
      ?? outputs.first(where: { vehiclePorts.contains($0.portType) })

    return [
      "available": true,
      "connected": car != nil,
      "deviceName": car?.portName,
      "permission": true,
    ]
  }
}
