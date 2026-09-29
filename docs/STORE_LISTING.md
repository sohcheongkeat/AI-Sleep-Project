# Store listing notes (DRAFT)

## Wording rules (wellness, not medical)

Use: "estimate", "track", "insights", "wellness", "may help", "talk to a doctor".

Avoid: "diagnose", "detect sleep apnea", "treat", "clinically accurate",
"medical-grade", naming any disorder as something the app finds.

Breathing-pause (apnea) detection is intentionally **not** in v1.

## Short description (≤ 80 chars, Google Play)

Track snoring and wake up gently in light sleep. Private, on-device.

## Full description (draft)

AI Sleep listens while you sleep to track snoring and estimate your sleep
stages, then wakes you during light sleep within a window you choose, so
mornings feel less abrupt.

• Smart alarm: pick your latest wake-up time and a 10–60 minute window.
• Snoring: see how often you snore, when, and listen to short clips.
• Morning report: sleep stages, sleep score, time to fall asleep,
  awakenings and personalised suggestions.
• Trends: see how alcohol, caffeine, exercise and more affect your nights.
• Private: sound is analysed on your phone. No account. Nothing uploaded.

AI Sleep provides wellness information only and is not a medical device.

## Google Play: Data safety form

- Data collected: **None** (processed on-device only, never transmitted).
- Data shared: **None**.
- Note: on-device processing that never leaves the device is not
  "collection" under Play's definitions. Double-check the current wording.
- Permissions to justify in the Play Console:
  - `RECORD_AUDIO`: core feature (sleep sound analysis).
  - `FOREGROUND_SERVICE_MICROPHONE`: continuous overnight tracking with the
    screen off. Play asks for a description and possibly a video.
  - `USE_EXACT_ALARM`: the app is an alarm clock. Play restricts this to
    alarm/calendar apps; the smart alarm qualifies.
  - `USE_FULL_SCREEN_INTENT`: the alarm screen. Allowed for alarm apps.

## Apple App Store

- App Privacy ("nutrition label"): **Data Not Collected**.
- Background audio: App Review checks that the `audio` background mode is
  used for audible or recording purposes. Explain in review notes that the
  app records overnight for sleep tracking while the screen is off.
- Health claims: guideline 1.4.1. Keep all copy in wellness terms; include
  the disclaimer in the description and in the app (already shown on first
  run and in reports).
- Category: Health & Fitness (or Lifestyle).

## Assets still needed

- App name (placeholder: "AI Sleep")
- Icon (1024×1024)
- Screenshots (render them with the screen tests, or capture from a device)
- Privacy policy URL (host `docs/PRIVACY_POLICY.md` once finalised)
- Support email
