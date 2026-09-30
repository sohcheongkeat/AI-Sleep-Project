import 'dart:async';
import 'dart:typed_data';

import 'package:ai_sleep/services/tracking_controller.dart';

import 'synthetic_audio.dart';

/// Phone stand-in: the microphone plays [SyntheticAudio], the clock advances
/// 100 ms per frame, and alarm calls are recorded.
class AudioPlatform implements TrackingPlatform {
  AudioPlatform(this.start) : clock = start;

  DateTime clock;
  final DateTime start;
  void Function(Float64List)? _onFrame;
  DateTime? scheduled;
  final ringNowAt = <DateTime>[];
  final _ringing = StreamController<bool>.broadcast();

  @override
  Future<bool> micPermission() async => true;
  @override
  Future<void> startAudio(void Function(Float64List) cb) async => _onFrame = cb;
  @override
  Future<void> stopAudio() async {}
  @override
  Future<void> startOvernightService() async {}
  @override
  Future<void> stopOvernightService() async {}
  @override
  Future<void> scheduleAlarm(DateTime at) async => scheduled = at;
  @override
  Future<void> ringAlarmNow() async => ringNowAt.add(clock);
  @override
  Future<void> stopAlarm() async {}
  @override
  Stream<bool> get alarmRinging => _ringing.stream;
  @override
  DateTime now() => clock;

  /// The OS-level alarm starts ringing.
  void ring() => _ringing.add(true);

  void play(SyntheticAudio audio) {
    for (var i = 0; i < audio.totalFrames; i++) {
      clock = clock.add(const Duration(milliseconds: 100));
      _onFrame!(audio.nextFrame());
    }
  }
}

