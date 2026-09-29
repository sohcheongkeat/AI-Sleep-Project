import 'dart:math' as math;
import 'dart:typed_data';

/// In-place iterative radix-2 FFT. [re] and [im] must have the same
/// power-of-two length.
void fft(Float64List re, Float64List im) {
  final n = re.length;
  assert(n == im.length && n > 0 && (n & (n - 1)) == 0, 'length must be a power of two');

  // Bit-reversal permutation.
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }

  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wRe = math.cos(ang);
    final wIm = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var curRe = 1.0;
      var curIm = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final a = i + k;
        final b = a + len ~/ 2;
        final xRe = re[b] * curRe - im[b] * curIm;
        final xIm = re[b] * curIm + im[b] * curRe;
        re[b] = re[a] - xRe;
        im[b] = im[a] - xIm;
        re[a] += xRe;
        im[a] += xIm;
        final nextRe = curRe * wRe - curIm * wIm;
        curIm = curRe * wIm + curIm * wRe;
        curRe = nextRe;
      }
    }
  }
}

int nextPowerOfTwo(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}
