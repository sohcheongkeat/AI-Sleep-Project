import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../core/smart_alarm.dart';

/// User preferences, stored as a small JSON file on the device.
class Settings extends ChangeNotifier {
  Settings(this._file);

  final File _file;

  TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
  int windowMinutes = defaultWindowMinutes;
  bool alarmEnabled = true;
  bool saveClips = true;
  int clipRetentionDays = 30;
  bool acceptedDisclaimer = false;

  Future<void> load() async {
    if (!await _file.exists()) return;
    try {
      final j = jsonDecode(await _file.readAsString()) as Map<String, Object?>;
      wakeTime = TimeOfDay(hour: j['wakeHour'] as int? ?? 7, minute: j['wakeMinute'] as int? ?? 0);
      windowMinutes = ((j['windowMinutes'] as int?) ?? defaultWindowMinutes)
          .clamp(minWindowMinutes, maxWindowMinutes);
      alarmEnabled = j['alarmEnabled'] as bool? ?? true;
      saveClips = j['saveClips'] as bool? ?? true;
      clipRetentionDays = j['clipRetentionDays'] as int? ?? 30;
      acceptedDisclaimer = j['acceptedDisclaimer'] as bool? ?? false;
    } on FormatException {
      // Corrupt settings: keep defaults.
    }
  }

  Future<void> update(void Function(Settings s) change) async {
    change(this);
    notifyListeners();
    await _file.writeAsString(jsonEncode({
      'wakeHour': wakeTime.hour,
      'wakeMinute': wakeTime.minute,
      'windowMinutes': windowMinutes,
      'alarmEnabled': alarmEnabled,
      'saveClips': saveClips,
      'clipRetentionDays': clipRetentionDays,
      'acceptedDisclaimer': acceptedDisclaimer,
    }));
  }

  /// The next occurrence of [wakeTime] after [now].
  DateTime nextWakeTime(DateTime now) {
    var t = DateTime(now.year, now.month, now.day, wakeTime.hour, wakeTime.minute);
    // Build tomorrow from calendar fields, not +24h, so DST changes don't shift it.
    if (!t.isAfter(now)) t = DateTime(now.year, now.month, now.day + 1, wakeTime.hour, wakeTime.minute);
    return t;
  }
}
