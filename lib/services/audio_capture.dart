import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../core/features.dart';

/// Streams raw microphone audio as fixed 100 ms frames of float samples.
/// Audio is processed in memory and never written to disk, except for the
/// short snore clips the tracking controller chooses to keep.
class AudioCapture {
  static const sampleRate = 16000;
  static const frameSize = 1600; // 100 ms
  static const frameRate = sampleRate / frameSize;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final _pending = BytesBuilder(copy: false);

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start(void Function(Float64List frame) onFrame) async {
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      // Raw sound is needed: processing would remove the snores and breaths.
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.mic),
    ));
    const frameBytes = frameSize * 2;
    _sub = stream.listen((chunk) {
      _pending.add(chunk);
      if (_pending.length < frameBytes) return;
      final all = _pending.takeBytes();
      var offset = 0;
      for (; offset + frameBytes <= all.length; offset += frameBytes) {
        onFrame(pcm16ToFloat(Uint8List.sublistView(all, offset, offset + frameBytes)));
      }
      if (offset < all.length) _pending.add(Uint8List.sublistView(all, offset));
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _pending.clear();
    await _recorder.stop();
  }

  Future<void> dispose() => _recorder.dispose();
}
