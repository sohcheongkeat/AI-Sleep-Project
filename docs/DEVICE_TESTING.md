# Device testing checklist

The detection logic is unit-tested with simulated nights, and every screen is
render-tested, but the parts below depend on real phones and could not be run
in the environment where the app was built. Test on at least one recent
iPhone and one Android phone (ideally a Samsung or Xiaomi, which are
aggressive about killing background apps).

## 1. Overnight survival (most important)

- [ ] Start tracking, lock the phone, leave it 8 h on the charger. Report
      covers the full night with no gaps.
- [ ] Same, not charging: note battery use.
- [ ] Android: tracking notification is visible all night.
- [ ] Android: with battery optimisation ON, does tracking survive? If not,
      prompt users to use Settings → "Allow running overnight".
- [ ] Kill the app mid-night: the deadline alarm still rings; the night up
      to the last autosave (every 10 min) is in History.
- [ ] Phone call or another app using audio mid-night: tracking resumes
      afterwards, and the timeline stays aligned with the clock.

## 2. Alarm

- [ ] Deadline alarm rings at the set time, screen locked, both platforms.
- [ ] Smart alarm: set wake-by ~2 h after bedtime with a 30 min window. Does
      it ring early, during a stir?
- [ ] Alarm is audible with the phone on silent / Do Not Disturb (Android
      alarm stream; iOS behaviour depends on the alarm plugin).
- [ ] While the mic is recording, the alarm sound still plays (iOS audio
      session: recording and playback must coexist).
- [ ] "I'm up" stops the alarm and opens the report.

## 3. Detection calibration

Record a few real nights and compare with what you remember or with a
wearable. Tune the defaults in `lib/core/burst_detectors.dart` and
`lib/core/stager.dart`:

- [ ] Snores: listen to the saved clips. Are they actually snores? Are loud
      snores missed? (`thresholdDb`, `minLowRatio`)
- [ ] Fan / air conditioner noise: no false snores, noise floor adapts.
- [ ] Turning over registers as movement; a partner's movement also will.
- [ ] Breathing regularity is detectable at 1 m (check the `rg` column in
      the 30-second CSV export). If it is always empty, the phone is too far
      or the room too noisy, and staging falls back to movement and snoring.

## 4. Permissions and first run

- [ ] Denying the microphone shows a clear message.
- [ ] Android 13+: the notification permission prompt appears.
- [ ] Android 14+: the foreground service starts only after the mic is granted.
- [ ] Disclaimer shows once, before the first night.
