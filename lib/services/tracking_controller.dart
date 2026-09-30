import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/burst_detectors.dart';
import '../core/features.dart';
import '../core/night_record.dart';
import '../core/session.dart';
import '../core/smart_alarm.dart';
import '../core/stager.dart';
import '../data/night_repository.dart';
import '../data/wav.dart';
import 'alarm_service.dart';
import 'audio_capture.dart';
import 'overnight_service.dart';

/// The device-specific pieces the controller needs, so the overnight flow
/// can be tested without a phone.
abstract class TrackingPlatform {
  Future<bool> micPermission();
  Future<void> startAudio(void Function(Float64List frame) onFrame);
  Future<void> stopAudio();
  Future<void> startOvernightService();
  Future<void> stopOvernightService();
  Future<void> scheduleAlarm(DateTime at);
  Future<void> ringAlarmNow();
  Future<void> stopAlarm();
  Stream<bool> get alarmRinging;
  DateTime now();
}

class DeviceTrackingPlatform implements TrackingPlatform {
  late final _capture = AudioCapture();

  @override
  Future<bool> micPermission() => _capture.hasPermission();
  @override
  Future<void> startAudio(void Function(Float64List) onFrame) => _capture.start(onFrame);
  @override
  Future<void> stopAudio() => _capture.stop();
  @override
  Future<void> startOvernightService() => OvernightService.start();
  @override
  Future<void> stopOvernightService() => OvernightService.stop();
  @override
  Future<void> scheduleAlarm(DateTime at) => AlarmService.scheduleDeadline(at);
  @override
  Future<void> ringAlarmNow() => AlarmService.ringNow();
  @override
  Future<void> stopAlarm() => AlarmService.stop();
  @override
  Stream<bool> get alarmRinging => AlarmService.ringing;
  @override
  DateTime now() => DateTime.now();
}

enum TrackingState { idle, tracking, ringing }

class StartResult {
  const StartResult.ok() : error = null;
  const StartResult.failed(this.error);
  final String? error;
  bool get ok => error == null;
}

/// Runs one night: microphone → features → session (stages, snores, alarm),
/// saving snore clips along the way and the night record at the end.
class TrackingController extends ChangeNotifier {
  TrackingController({required this.repository, TrackingPlatform? platform})
      : platform = platform ?? DeviceTrackingPlatform();

  final NightRepository repository;
  final TrackingPlatform platform;

  static const maxClipsPerNight = 30;
  static const minSecondsBetweenClips = 300;
  static const maxClipSeconds = 5.0;
  static const autosaveEpochs = 20; // every 10 minutes
  static const minNightLength = Duration(minutes: 2);

  final _extractor = FeatureExtractor(
    sampleRate: AudioCapture.sampleRate,
    frameSize: AudioCapture.frameSize,
  );

  TrackingState state = TrackingState.idle;
  SleepSession? session;
  DateTime? startedAt;
  DateTime? wakeBy;
  int? windowMinutes;
  DateTime? alarmAt;
  String? alarmReason;
  bool _saveClips = true;

  late String _nightId;
  final List<SnoreClip> _clips = [];
  final _ring = SampleRing((AudioCapture.sampleRate * maxClipSeconds).round());
  int _frames = 0;
  double _timeOffset = 0;
  double _lastClipT = -minSecondsBetweenClips.toDouble();
  StreamSubscription<bool>? _ringingSub;
  Future<void> _saves = Future.value();

  /// Saves run one after another so an autosave can't overwrite a later save.
  Future<void> _queueSave(NightRecord r) =>
      _saves = _saves.then((_) => repository.save(r)).catchError((Object e) {
        // Keep the queue alive for the next save, but don't hide the failure.
        debugPrint('Saving night ${r.id} failed: $e');
      });

  Stage? get currentStage => session?.currentStage;
  int get snoreCount => session?.snores.length ?? 0;

  Future<StartResult> start({DateTime? wakeBy, int windowMinutes = defaultWindowMinutes,
      bool saveClips = true}) async {
    if (state != TrackingState.idle) return const StartResult.failed('Already tracking');
    if (!await platform.micPermission()) {
      return const StartResult.failed(
          'Microphone access is needed to hear snoring and breathing. '
          'You can allow it in your phone\'s settings.');
    }
    final now = platform.now();
    startedAt = now;
    this.wakeBy = wakeBy;
    this.windowMinutes = wakeBy == null ? null : windowMinutes;
    alarmAt = null;
    alarmReason = null;
    _saveClips = saveClips;
    _nightId = '${now.millisecondsSinceEpoch}';
    _clips.clear();
    _frames = 0;
    _timeOffset = 0;
    _lastClipT = -minSecondsBetweenClips.toDouble();

    session = SleepSession(
      start: now,
      frameRate: AudioCapture.frameRate,
      alarm: wakeBy == null ? null : SmartAlarm(wakeBy: wakeBy, windowMinutes: windowMinutes),
      onEpoch: _onEpoch,
      onSnore: _onSnore,
      onAlarm: _onSmartAlarm,
    );

    // The OS-level deadline alarm is the safety net if anything else fails.
    if (wakeBy != null) await platform.scheduleAlarm(wakeBy);
    _ringingSub = platform.alarmRinging.listen((ringing) {
      if (ringing && state == TrackingState.tracking) {
        state = TrackingState.ringing;
        alarmAt ??= platform.now();
        alarmReason ??= 'Wake-up time reached';
        notifyListeners();
      }
    });

    await platform.startOvernightService();
    await platform.startAudio(_onFrame);
    state = TrackingState.tracking;
    notifyListeners();
    return const StartResult.ok();
  }

  void _onEpoch(Epoch e) {
    notifyListeners();
    // Autosave so a crash or a killed app doesn't lose the whole night.
    if ((e.index + 1) % autosaveEpochs == 0) _queueSave(_buildRecord());
  }

  void _onFrame(Float64List samples) {
    final s = session;
    if (s == null) return;
    // Time from the sample count, re-synced to the wall clock if audio was
    // interrupted (e.g. by a phone call) so epochs stay aligned with real time.
    var t = _frames / AudioCapture.frameRate + _timeOffset;
    final wall = platform.now().difference(startedAt!).inMilliseconds / 1000;
    if (wall - t > 5) {
      _timeOffset += wall - t;
      t = wall;
    }
    _frames++;
    _ring.addAll(samples);
    s.addFrame(t, _extractor.compute(samples));
  }

  void _onSnore(SoundEvent ev) {
    notifyListeners();
    if (!_saveClips || _clips.length >= maxClipsPerNight) return;
    if (ev.start - _lastClipT < minSecondsBetweenClips) return;
    _lastClipT = ev.start;
    // The event is reported as soon as the snore ends, so the ring buffer
    // holds the whole snore plus a little lead-in.
    final seconds = math.min(maxClipSeconds, ev.duration + 1.5);
    final samples = _ring.last((seconds * AudioCapture.sampleRate).round());
    final name = '${_nightId}_${_clips.length}.wav';
    _clips.add(SnoreClip(file: name, offsetS: ev.start));
    unawaited(File('${repository.clipsDir.path}/$name')
        .writeAsBytes(encodeWav(samples, AudioCapture.sampleRate)));
  }

  void _onSmartAlarm(String reason, DateTime at) {
    if (state != TrackingState.tracking) return;
    alarmReason = reason;
    alarmAt = platform.now();
    state = TrackingState.ringing;
    notifyListeners();
    unawaited(platform.ringAlarmNow());
  }

  Future<void> stopAlarm() => platform.stopAlarm();

  /// Ends the night and saves it. Returns null if nothing was recorded.
  Future<NightRecord?> finish() async {
    final s = session;
    if (s == null) return null;
    await platform.stopAudio();
    await platform.stopOvernightService();
    await platform.stopAlarm();
    await _ringingSub?.cancel();
    _ringingSub = null;

    s.finish();
    final record = _buildRecord();
    session = null;
    state = TrackingState.idle;
    notifyListeners();

    await _saves;
    // Stopped straight away (an accidental start): keep nothing.
    if (record.epochs.isEmpty || record.end.difference(record.start) < minNightLength) {
      await repository.delete(record); // also removes any clips and autosaves
      return null;
    }
    await _queueSave(record);
    return record;
  }

  NightRecord _buildRecord() {
    final s = session!;
    return NightRecord(
      id: _nightId,
      start: startedAt!,
      end: platform.now(),
      epochs: List.of(s.epochs),
      snoreOffsetsS: [for (final e in s.snores) e.start],
      wakeBy: wakeBy,
      windowMinutes: windowMinutes,
      alarmAt: alarmAt,
      alarmReason: alarmReason,
      clips: List.of(_clips),
    );
  }
}
