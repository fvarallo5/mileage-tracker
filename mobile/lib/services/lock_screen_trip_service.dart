import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

typedef LockScreenTripHandler = Future<String> Function();

/// Lock-screen / notification shade trip controls with live mile updates.
///
/// Android: ongoing public notification with Start / Stop actions.
/// iOS: time-sensitive banner with the same actions (Live Activity would need
/// a Widget Extension — this covers lock-screen actions + live text updates).
class LockScreenTripService {
  LockScreenTripService();

  static const notificationId = 7101;
  static const channelId = 'trektrack_trip_controls';
  static const actionStart = 'start_trip';
  static const actionStop = 'stop_trip';
  static const _enabledKey = 'lock_screen_trip_controls';
  static const _pendingActionKey = 'pending_lock_screen_action';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<String?> lastMessage = ValueNotifier(null);

  LockScreenTripHandler? _onStart;
  LockScreenTripHandler? _onStop;
  bool enabled = true;
  bool _initialized = false;
  bool _tracking = false;
  double _miles = 0;
  DateTime? _lastPublish;

  /// Background isolate entry — queues action for the next app frame.
  @pragma('vm:entry-point')
  static void onBackgroundResponse(NotificationResponse response) {
    unawaited(_queueAction(response.actionId ?? response.payload));
  }

  static Future<void> _queueAction(String? action) async {
    if (action != actionStart && action != actionStop) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingActionKey, action!);
  }

  Future<void> initialize({
    required LockScreenTripHandler onStart,
    required LockScreenTripHandler onStop,
  }) async {
    _onStart = onStart;
    _onStop = onStop;

    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'trektrack_trip',
          actions: [
            DarwinNotificationAction.plain(
              actionStart,
              'Start trip',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              actionStop,
              'Stop & save',
              options: {
                DarwinNotificationActionOption.foreground,
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          'Trip controls',
          description: 'Lock screen Start / Stop and live trip miles',
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;

    if (enabled) {
      await requestPermissions();
      await _drainPendingAction();
      await publish(tracking: false);
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return status.isGranted || status.isLimited;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          ) ??
          false;
      return granted;
    }
    return true;
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) {
      await clear();
      return;
    }
    final ok = await requestPermissions();
    if (ok) {
      await publish(tracking: _tracking, miles: _miles);
    }
  }

  Future<void> publish({
    required bool tracking,
    double miles = 0,
    bool isAuto = false,
  }) async {
    if (!_initialized || !enabled) return;

    _tracking = tracking;
    _miles = miles;

    // Throttle live mile updates so we don't hammer the notification manager.
    final now = DateTime.now();
    if (tracking &&
        _lastPublish != null &&
        now.difference(_lastPublish!) < const Duration(seconds: 2)) {
      return;
    }
    _lastPublish = now;

    final title = tracking
        ? (isAuto ? 'Auto trip in progress' : 'Trip in progress')
        : '${AppConfig.appName} ready';
    final body = tracking
        ? '${miles.toStringAsFixed(2)} mi · Tap Stop when you park'
        : 'Start a trip from the lock screen or notification';

    final androidActions = tracking
        ? <AndroidNotificationAction>[
            const AndroidNotificationAction(
              actionStop,
              'Stop & save',
              showsUserInterface: true,
              cancelNotification: false,
            ),
          ]
        : <AndroidNotificationAction>[
            const AndroidNotificationAction(
              actionStart,
              'Start trip',
              showsUserInterface: true,
              cancelNotification: false,
            ),
          ];

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Trip controls',
        channelDescription: 'Lock screen Start / Stop and live trip miles',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
        actions: androidActions,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: false,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: 'trektrack_trip',
        threadIdentifier: 'trektrack_trip',
      ),
    );

    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: tracking ? actionStop : actionStart,
    );
  }

  /// Force-refresh even if throttle would skip (e.g. start/stop transitions).
  Future<void> publishImmediate({
    required bool tracking,
    double miles = 0,
    bool isAuto = false,
  }) async {
    _lastPublish = null;
    await publish(tracking: tracking, miles: miles, isAuto: isAuto);
  }

  Future<void> clear() async {
    if (!_initialized) return;
    await _plugin.cancel(id: notificationId);
  }

  Future<void> _onResponse(NotificationResponse response) async {
    final action = response.actionId?.isNotEmpty == true
        ? response.actionId
        : response.payload;
    await _handleAction(action);
  }

  Future<void> _drainPendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    final action = prefs.getString(_pendingActionKey);
    if (action == null) return;
    await prefs.remove(_pendingActionKey);
    await _handleAction(action);
  }

  Future<void> _handleAction(String? action) async {
    if (action == null) return;
    final handler = switch (action) {
      actionStart => _onStart,
      actionStop => _onStop,
      _ => null,
    };
    if (handler == null) return;
    try {
      final message = await handler();
      lastMessage.value = message;
    } catch (e) {
      lastMessage.value = e.toString();
    }
  }
}
