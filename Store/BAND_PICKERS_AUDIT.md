# Three-band pickers — build 7

## Behavior

- Replaces the 5-by-5 grid with three separate five-option pickers: Low, Mid,
  and High. Every band uses Off, -18, -12, -6, and 0 dB relative to its own
  maximum. Active sample gains are `10^(dB/20)`; Off is exactly zero.
- Low is now adjustable through the existing production gain/fade path. Filter
  coefficients, random streams, maximum gains, and playback recovery are unchanged.
  Every source keeps running in the same graph at zero gain. Changes use the
  existing 600 ms smoothstep fade, including rapid changes and mute/restore.
- Existing grid preferences default Low to 4. Explicitly saved Low 0 stays 0.
  All 125 combinations are saved and restored. All three Off intentionally
  silences output and shows "All bands off" while the engine remains running.
- Pure-black screen; low/red, mid/green, high/blue buttons; a small steady
  infinity mark combines the selected intensities. Selection also uses a border
  and checkmark, accessible labels, and selected traits. Targets are at least
  44 points. A scroll view supports compact screens and larger text.
- Installed display name and Now Playing title are provisionally Persistent
  Noise. The app icon and Now Playing artwork use an RGB infinity ribbon on
  black. Bundle identifier remains `io.niemo.JustBrownNoise`. The dedicated pause
  button remains pending the user's decision about simplifying playback controls.

## Validation

29 core tests passed, including measured emitted power at startup and after
live changes for all three bands, migration, clamping, and saved zero values.
Five actual iOS-engine integration tests passed, including cycling all 125 mixes
without restarting the engine or source clocks. The UI test passed on iPhone:
all 15 choices, selection and independent bands, minimum target sizes, background
render continuity, pause behavior, and saved values across relaunch.

Release simulator and device archive builds passed. Release layouts were
visually inspected on iPhone 17 Pro and iPad Pro 13-inch simulators. The app icon
was inspected independently. Preview images are in `Store/previews/build-7/`.

135 Apple-engine offline renders were checked:

- All 125 combinations, 48 kHz stereo, eight seconds each.
- All-off, individual maximum bands, and maximum mix, 44.1 kHz, 60 seconds each.
- Rapid changes at 44.1 and 48 kHz, 60 seconds each.
- Repeated all-off/maximum-mix changes at 48 kHz, 60 seconds.
- Maximum mix at 16 and 48 kHz mono, 60 seconds each.

All 125 mixes matched the independently rendered layers with the requested
decibel gains (maximum sample difference 2.21e-8). All 25 previous balances with
Low at 4 matched build 6 sample-for-sample, including startup. All-off rendered
exact zero; repeated mute tests settled to zero after fades and conversion tails
and resumed audible output. Active mixes had no unexpected silent blocks. All
renders had finite samples, equal stereo channels, and zero render retries.

Maximum estimated intersample peak using 8x oversampling was -13.29 dBFS in
these renders. No limiting, compression, normalization, or extra gain was added.
Lowering Low cannot increase the sum of the independent source peak bounds;
the existing combined bound remains below 0.959 before sample-rate conversion.

Measurements: `band-measurements.json`.
Renderer and analysis: `scripts/render-bands.swift`, `scripts/check-bands.py`.
Logs and result bundle: `build/band-pickers-v7/`, including
`IntegrationAndUI.xcresult`, `swift-test.log`, and `analysis.log`.

These are automated and simulator checks. Physical iPhone listening and overnight
playback of build 7 remain unverified. Earlier 48-hour accelerated endurance
runs cover the unchanged generators and filters; they were not repeated for
this gain-control and interface change.

## Distribution

Build 7 uploaded successfully at 2026-11-14 14:38:48 UTC. The Personal Testing
group was then verified as **1.0 (7), Testing**, with the build notes saved. The
tester's last installed build observed was 1.0 (6). Signed package and source
evidence is in `build-7-manifest.json`; live group evidence is in
`testflight-confirmation.json`. All recorded source and package hashes still
matched after upload.
The public App Store name, listing, support site, and pending build-6 submission
remain unchanged while the final name and playback controls are discussed.
