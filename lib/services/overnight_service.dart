import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process alive overnight.
///
/// Android: a foreground service of type "microphone" with an ongoing
/// notification (required to use the mic with the screen off).
/// iOS: nothing to do here — an active recording plus the "audio" background
/// mode in Info.plist keeps the app running.
class OvernightService {
  static void init() {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sleep_tracking',
        channelName: 'Sleep tracking',
        channelDescription: 'Shown while your night is being tracked',
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
  }

  /// Asks for the notification permission Android 13+ needs for the
  /// tracking notification.
  static Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: 'Tracking your sleep',
      notificationText: 'Tap to open. Keep your phone charging.',
      callback: keepAliveCallback,
    );
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void keepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_IdleHandler());
}

/// The service only exists to keep the process alive; all work happens in
/// the main isolate.
class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
