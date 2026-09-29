import 'stager.dart';

const minWindowMinutes = 10;
const maxWindowMinutes = 60;
const defaultWindowMinutes = 30;

/// Decides when to wake: at the first light sleep (N1) inside the window
/// before [wakeBy], and always at [wakeBy].
///
/// N1 is also how you *fall* asleep, so the alarm ignores N1 until
///   - at least [minSleep] has passed since tracking started, and
///   - deeper sleep (N2/N3) has been reached,
/// making the N1 we act on a lightening of sleep, not sleep onset.
class SmartAlarm {
  SmartAlarm({
    required this.wakeBy,
    this.windowMinutes = defaultWindowMinutes,
    this.minSleep = const Duration(minutes: 60),
  }) : assert(windowMinutes >= minWindowMinutes && windowMinutes <= maxWindowMinutes);

  final DateTime wakeBy;
  final int windowMinutes;
  final Duration minSleep;

  DateTime? _start;
  bool _reachedDeeper = false;
  bool _fired = false;

  DateTime get windowStart => wakeBy.subtract(Duration(minutes: windowMinutes));
  bool get fired => _fired;

  /// Returns a reason string when it's time to wake (only once), else null.
  String? update(DateTime now, Stage stage) {
    if (_fired) return null;
    _start ??= now;
    if (stage == Stage.n2 || stage == Stage.n3) _reachedDeeper = true;

    if (!now.isBefore(wakeBy)) return _fire('Wake-up time reached');

    final inWindow = !now.isBefore(windowStart);
    final sleptEnough = now.difference(_start!) >= minSleep;
    if (inWindow && sleptEnough && _reachedDeeper) {
      if (stage == Stage.n1) return _fire('Woke you in light sleep (N1)');
      if (stage == Stage.wake) return _fire('You were already stirring');
    }
    return null;
  }

  String _fire(String reason) {
    _fired = true;
    return reason;
  }
}
