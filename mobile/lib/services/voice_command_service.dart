import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_intents/flutter_app_intents.dart';

typedef VoiceCommandHandler = Future<String> Function();

class VoiceCommandService {
  VoiceCommandService({
    required this._onStartTrip,
    required this._onStopTrip,
  });

  static const _androidChannel = MethodChannel('com.mileagetracker/voice_commands');

  final VoiceCommandHandler _onStartTrip;
  final VoiceCommandHandler _onStopTrip;

  final ValueNotifier<String?> lastMessage = ValueNotifier(null);

  Future<void> initialize() async {
    if (Platform.isIOS) {
      await _registerSiriIntents();
    }
    if (Platform.isAndroid) {
      await _registerAndroidChannel();
    }
  }

  Future<void> _registerSiriIntents() async {
    final client = FlutterAppIntentsClient.instance;

    final startIntent = AppIntentBuilder()
        .identifier('start_trip')
        .title('Start Trip')
        .description('Start GPS mileage tracking')
        .build();

    final stopIntent = AppIntentBuilder()
        .identifier('stop_trip')
        .title('Stop Trip')
        .description('Stop tracking and save the current trip')
        .build();

    await client.registerIntent(startIntent, (_) async {
      final message = await _onStartTrip();
      lastMessage.value = message;
      return AppIntentResult.successful(
        value: message,
        needsToContinueInApp: true,
      );
    });

    await client.registerIntent(stopIntent, (_) async {
      final message = await _onStopTrip();
      lastMessage.value = message;
      return AppIntentResult.successful(
        value: message,
        needsToContinueInApp: true,
      );
    });

    await client.updateShortcuts();
  }

  Future<void> _registerAndroidChannel() async {
    _androidChannel.setMethodCallHandler((call) async {
      if (call.method == 'onVoiceCommand') {
        await _handleAndroidCommand(call.arguments as String?);
      }
    });

    final pending = await _androidChannel.invokeMethod<String>('getPendingAction');
    if (pending != null) {
      await _handleAndroidCommand(pending);
    }
  }

  Future<void> _handleAndroidCommand(String? action) async {
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