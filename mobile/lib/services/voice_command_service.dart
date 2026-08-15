import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef VoiceCommandHandler = Future<String> Function();

/// Handles Siri / App Intents (iOS) and shortcut intents (Android) via a
/// single MethodChannel — no third-party plugin.
class VoiceCommandService {
  VoiceCommandService({
    required this._onStartTrip,
    required this._onStopTrip,
  });

  static const channelName = 'com.mileagetracker/voice_commands';
  static const _channel = MethodChannel(channelName);

  final VoiceCommandHandler _onStartTrip;
  final VoiceCommandHandler _onStopTrip;

  final ValueNotifier<String?> lastMessage = ValueNotifier(null);

  Future<void> initialize() async {
    _channel.setMethodCallHandler(_onMethodCall);

    if (Platform.isAndroid) {
      final pending =
          await _channel.invokeMethod<String>('getPendingAction');
      if (pending != null) {
        await _handleCommand(pending);
      }
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'start_trip':
        return _run(_onStartTrip);
      case 'stop_trip':
        return _run(_onStopTrip);
      case 'onVoiceCommand':
        await _handleCommand(call.arguments as String?);
        return null;
      default:
        throw PlatformException(
          code: 'unsupported',
          message: 'Unknown voice command: ${call.method}',
        );
    }
  }

  Future<String> _run(VoiceCommandHandler handler) async {
    final message = await handler();
    lastMessage.value = message;
    return message;
  }

  Future<void> _handleCommand(String? action) async {
    final message = switch (action) {
      'start_trip' => await _onStartTrip(),
      'stop_trip' => await _onStopTrip(),
      _ => null,
    };
    if (message != null) {
      lastMessage.value = message;
    }
  }
}
