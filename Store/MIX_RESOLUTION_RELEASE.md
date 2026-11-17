# Six mix choices — EverNoise 1.1 (30)

The first active button previously jumped from silence to −18 dB relative
weight. Build 30 inserts a trace at −30 dB. Every former active weight remains
available, with the same filters, shared loudness normalization, dynamics and
peak ceilings. This changes the available mixes, not the sound of saved mixes.

| Choice, counting Off first | Relative gain | Relative power | Sample amplitude |
| --- | --- | --- | --- |
| 1: hollow circle | Off | 0% | 0 |
| 2: smallest dot | −30 dB | 0.1% | 0.031623 |
| 3 | −18 dB | 1.5849% | 0.125893 |
| 4 | −12 dB | 6.3096% | 0.251189 |
| 5 | −6 dB | 25.1189% | 0.501187 |
| 6: largest dot | 0 dB | 100% | 1 |

Power is `10^(dB/10)`; sample amplitude is `10^(dB/20)`. The trace supplies
15.8489 times less power than the next choice. The maximum relative weight and
the digital output ceiling do not increase. These percentages describe band
weights before the common normalization, not a percentage of final acoustic
loudness or a percentage of each band's normalized output energy.

The relative weights enter the existing K-weighted unit-vector calculation.
Consequently, one band playing alone has the same normalized loudness at any
nonzero choice. Adding a trace matters relative to the other active bands.
All Off is exact silence; App Loudness still sets the shared target. Settings
explains this behavior on iOS and tvOS.

## Preferences and visuals

The old coordinate system is read as `0 → 0`, `1…4 → 2…5`. A complete new
mix is stored as one property-list dictionary under `mixLevelsV2`; old keys
are left intact. Reads are side-effect free, cannot migrate twice, and an
incomplete new value falls back to the old intact coordinates. The prior
−12/−12/−18 dB default becomes buttons **4/4/3** in Low/Mid/High order,
counting Off first. Old Brown/Gray/White presets and the grid's fixed low
level also retain their weights. Rolling back the app restores the most
recent old-format balance; new trace choices have no counterpart in that build.

The glass button rim, muted rose/sage/periwinkle palette, High/Mid/Low order,
large touch targets, and paused grayscale remain. The dot diameter is
`22 * power^0.25` points, making area proportional to the square root of power;
the tint's linear-light intensity is `power^(1/3)`. This deliberate visual
compression leaves the trace dot about 3.9 points wide instead of making it
subpixel. It is a legible relative-strength indicator, not a calibrated audio
meter. The hollow Off mark is a quiet six-point outline. VoiceOver announces
the band, position, and relative dB. The retained notched-slider component
also understands all six choices.

## Validation

- 55 core tests: all 125 migrations, all 216 new preference combinations,
  Swift/DSP level agreement, normalization, exact silence, buffer partitioning,
  clipping bounds, continuous retargets and playback lifecycle.
- 39 iOS and 17 tvOS integration tests passed. Live-engine selection traverses
  all 216 mixes without restarting audio. Existing Max-worker checks still pass.
- All 216 mixes at default and maximum App Loudness: maximum measured
  K-weighted target error **0.07114 LU**; maximum 16× reconstructed peak
  **0.6556975 (−3.67 dBTP)**. Every result remains below the −2 dBTP acceptance
  ceiling. The peak protector's unchanged adversarial test reaches 0.707938.
- 42 actual AVAudioEngine conversion renders at 8–192 kHz, mono/stereo and
  rapid controls including the trace: maximum reconstructed peak **0.575124**.
- Independent build-29 comparison: **19,120,000 samples per channel** match
  bit for bit across all 125 legacy mixes, three offsets, the default and
  continuous mix/stereo/offset changes. All 216 new mixes match an independently
  composed source calculation within **2.86e−9** sample amplitude. Trace-level
  buffer partitioning is bit-identical over 192,013 frames.
- Two accelerated hours: **345,600,000 frames per channel**, 231 changes,
  84,375 buffers, no invalid or unexpectedly silent buffer, peak 0.667301,
  and no peak-protector engagement. Slow gain stays 0.996425–1.002557.
- Undefined-behavior and bounds instrumentation: 2,160 commands,
  **4,466,392 frames per channel**, invalid-index clamps, canaries and exact
  all-off silence pass. AddressSanitizer is not claimed; this host's runtime
  failed before main during the preceding release's attempt.

UI validation and final delivery are recorded in the build manifest and
release status after completion. No new physical-device listening or overnight
acoustic measurement is claimed. Digital peaks do not determine room sound
pressure or guarantee freedom from distortion in every speaker or output route.

Reproduction tools: `scripts/check-mix-resolution.py`,
`scripts/check-loudness.py`, `scripts/check-loudness-conversion.py`,
`scripts/loudness-endurance.c`, and `scripts/check-mix-sanitized.c`.
The baseline library is built from the build-29 `BNMixRenderer.c` at commit
`1503245`; all filter and dynamics headers are unchanged.
