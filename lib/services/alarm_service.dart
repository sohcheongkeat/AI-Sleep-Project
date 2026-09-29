import 'dart:io';

import 'package:alarm/alarm.dart';

/// Wraps the native alarm. The deadline alarm is registered with the OS at
/// bedtime, so it rings even if tracking stops unexpectedly; when light sleep
/// is detected inside the window, the same alarm is moved to "now".
class AlarmService {
  static const _id = 7;

  static Future<void> init() => Alarm.init();

  static AlarmSettings _settings(DateTime at) => AlarmSettings(
        id: _id,
        dateTime: at,
        // Null uses the device's default alarm sound; fade in gently.
        volumeSettings: VolumeSettings.fade(fadeDuration: const Duration(seconds: 45)),
        notificationSettings: const NotificationSettings(
          title: 'Good morning',
          body: 'Time to wake up',
          stopButton: 'Stop',
        ),
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: Platform.isIOS,
        androidFullScreenIntent: true,
      );

  static Future<void> scheduleDeadline(DateTime at) => Alarm.set(alarmSettings: _settings(at));

  static Future<void> ringNow() =>
      Alarm.set(alarmSettings: _settings(DateTime.now().add(const Duration(seconds: 2))));

  static Future<void> stop() => Alarm.stop(_id);

  static Stream<bool> get ringing =>
      Alarm.ringing.map((set) => set.alarms.any((a) => a.id == _id));
}
