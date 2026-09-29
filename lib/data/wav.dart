import 'dart:typed_data';

/// Encodes mono float samples in [-1, 1] as a 16-bit PCM WAV file.
Uint8List encodeWav(List<double> samples, int sampleRate) {
  const bytesPerSample = 2;
  final dataLen = samples.length * bytesPerSample;
  final b = ByteData(44 + dataLen);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little); // PCM chunk size
  b.setUint16(20, 1, Endian.little); // PCM format
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  b.setUint16(32, bytesPerSample, Endian.little);
  b.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    b.setInt16(44 + i * 2, v, Endian.little);
  }
  return b.buffer.asUint8List();
}

/// Fixed-size ring buffer of the most recent audio samples, so a clip can
/// include the moments just before a snore was recognised.
class SampleRing {
  SampleRing(int capacity) : _buf = Float64List(capacity);

  final Float64List _buf;
  int _written = 0;

  void addAll(List<double> samples) {
    for (final s in samples) {
      _buf[_written % _buf.length] = s;
      _written++;
    }
  }

  /// The most recent [count] samples, oldest first.
  List<double> last(int count) {
    final n = count.clamp(0, _written < _buf.length ? _written : _buf.length);
    return [for (var i = _written - n; i < _written; i++) _buf[i % _buf.length]];
  }
}
