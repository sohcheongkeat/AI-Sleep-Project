# Sleep Coach

A Flutter app for iOS and Android that listens overnight through the phone's
microphone to track snoring, estimate sleep stages, and wake you during light
sleep (N1) inside a window you choose before your wake-up time.

Everything runs on the phone. No account, no server, no cloud AI.

> Sleep Coach estimates sleep stages from sound. It is not a medical device and
> does not diagnose or treat any condition.

## Features (v1)

- **Smart alarm**: set a latest wake-up time and a 10–60 min window (default
  30). It rings at the first light sleep in the window, and at the wake-up
  time at the latest.
- **Snoring**: count, snores per hour, a timeline, and up to 30 short clips
  per night (kept on the phone, deleted after 7–90 days).
- **Sleep stages** every 30 s: Awake / Light (N1) / Sleep (N2) / Deep (N3).
- **Morning report**: hypnogram, sleep score, time to fall asleep, total
  sleep, efficiency, awakenings, stage breakdown, snoring, suggestions.
- **Trends**: score over time, 7- and 30-night averages, and tag effects
  (e.g. "Alcohol" nights vs. others).
- **Export**: nightly CSV, 30-second CSV, full JSON.

## How the detection works

All in `lib/core/` (pure Dart, unit-tested):

| Step | File | What it does |
|---|---|---|
| Features | `features.dart`, `fft.dart` | Every 100 ms: loudness in the 60–500 Hz snore band, the 2–7.5 kHz rustle band and the 250–2000 Hz breath band |
| Snores & movement | `burst_detectors.dart` | Bursts above each band's adaptive noise floor. Snore = +15 dB in the snore band for 0.3–3.5 s. Movement = +20 dB in the rustle band for 0.4–20 s. (Audible breathing reaches about +12–14 dB, so it doesn't count as either.) |
| Breathing | `breathing.dart` | Rate and regularity from autocorrelation of the breath-band loudness over 60 s |
| Stage | `stager.dart` | Rules per 30 s epoch (below) |
| Alarm | `smart_alarm.dart` | Fires on N1 or wake inside the window, only after ≥ 60 min of tracking **and** after deeper sleep was reached |

Stage rules, in order:
1. Lots of movement → Awake. Brief movement → N1 (sleep lightening), or
   still Awake if you were just awake.
2. Snoring → N2 (N3 if still for 10+ min with very regular breathing).
3. Regular breathing → N2/N3; right after waking it is N1 first.
4. Uneven breathing, no snoring → N1.
5. N1 lasts at most ~7 min; deep sleep comes in blocks capped at 30 min
   (first 3 h of sleep) or 10 min (later), and repeats only after sleep lightens.

**Why the sleep-onset guard matters:** N1 is also the stage you pass through
while falling asleep. Without the guard, the alarm could ring minutes after
you lie down.

**Accuracy:** true N1 is defined by EEG (brain waves). Sound can only show
its signs. Expect the stage estimate to be rough, especially N2 vs. N3. The
OS-level alarm at the wake-up time is always set, so you are woken even if
detection misses light sleep.

## Project layout

```
lib/core/       detection, alarm logic, metrics, advice, trends (no Flutter)
lib/data/       JSON-per-night storage, WAV clips, CSV/JSON export
lib/services/   microphone, alarm, background service, settings, tracking
lib/ui/         screens and charts
test/           unit tests, screen render tests, and end-to-end tests:
                - e2e/full_night_audio_test: 7.5 h of synthesized bedroom audio
                  (breathing, snores, rustling, optional fan) through the whole
                  pipeline, smart alarm and saving
                - e2e/app_flow_test: drives the real screens from Tonight to
                  the morning report and History
docs/           plan, privacy policy draft, store listing notes, device tests
```

## Running

Requires Flutter 3.47+.

```sh
flutter pub get
flutter test                 # 47 tests, ~3 min (two full simulated nights)
flutter test test/core test/data test/services test/ui   # fast subset
flutter analyze
flutter run                  # on a connected phone
```

To render the screens to PNGs for review:

```sh
SCREENSHOT_DIR=/tmp/shots FLUTTER_ROOT=$(dirname $(dirname $(which flutter))) flutter test test/ui
```

## Platform setup (already done in this repo)

- **Android**: `RECORD_AUDIO`, a `microphone` foreground service (keeps
  tracking alive with the screen off), notification permission, exact-alarm
  and full-screen-intent permissions for the alarm, `minSdk` 23.
- **iOS**: `NSMicrophoneUsageDescription`, background modes `audio` and
  `fetch`, alarm plugin background task registration in `AppDelegate.swift`.

## Before release

See `docs/DEVICE_TESTING.md` and `docs/STORE_LISTING.md`. Still open:
app icon, bundle/application IDs, release signing, and on-device
testing (not possible in the cloud environment this was built in).
