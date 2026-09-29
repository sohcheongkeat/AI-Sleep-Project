# AI Sleep Project — v1 Plan (draft, awaiting approval)

A cross-platform mobile app that tracks snoring overnight and wakes the user
during light sleep (N1) inside a chosen window before their wake-up time.

## Decisions

| Topic | Decision |
|---|---|
| Platform | Native mobile, iOS + Android, **Flutter** (one codebase; Dart handles on-device audio DSP; small native bits for background mic + alarm) |
| Sensors | **Phone microphone only** (breathing, snoring, movement heard as rustling) |
| Alarm | Smart alarm: user sets latest wake time + window **10–60 min, default 30**; fires at first N1 in window, else at deadline |
| Snoring | Counts & stats, timeline, short audio clips (local, auto-delete) |
| Storage | **On the phone only**, with CSV/JSON export |
| Analysis | Nightly report, weekly trends, factor tagging, summary/advice |
| Summary/advice | **Rule-based, on-device** (lowest running cost; no server, no API fees) |
| Breathing-pause (apnea) detection | **Out of v1** (medical-claim risk) |
| Audience | App-store release |

## Key constraints

- **N1 is estimated, not measured.** Clinical N1 is defined by EEG. The app
  infers it from audio correlates: breathing slowing but irregular, no
  snoring (snoring is mostly N2/N3), brief movement sounds after stillness.
  All UI and store copy must say "estimate" and avoid medical claims.
- **Sleep-onset guard.** N1 also occurs when falling asleep. The alarm only
  acts on N1 after a minimum tracked time and after deeper sleep (N2/N3)
  has been reached.
- Background audio: Android foreground service (microphone type); iOS
  background audio mode. Phone should be charging overnight.

## v1 features

1. Overnight tracking (on-device audio processing, screen may be off)
2. Snore detection: count, snores/hour, timeline, clips
3. Stage estimate per 30 s epoch: Wake / N1 / N2 / N3
4. Smart alarm (window 10–60 min, default 30) with onset guard
5. Nightly report: hypnogram, sleep latency, total sleep, awakenings, snore stats, score
6. Weekly trends and factor tags (alcohol, caffeine, exercise, …)
7. Local storage + CSV/JSON export

## Build order

1. Pure-Dart detection core (snore, breathing, stager, alarm) + tests on simulated nights
2. Overnight audio capture + alarm, per platform
3. UI: start night, alarm settings, report, trends, tags
4. Local database, recording management, export
5. Store prep: permission strings, privacy policy, icons, wellness wording

## Open items

- User approval of this plan before implementation starts
- Confirm Flutter SDK can be installed in the dev environment
