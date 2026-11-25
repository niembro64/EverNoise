# Logarithmic grid levels — build 6

Version 1.0 (6), November 14, 2026. Corrects the mid/high gain scale from
linear amplitude to equal decibel steps between the active levels.

## Level mapping

Both axes use the same mapping relative to each layer's existing maximum:

| Grid level | Relative level | Sample amplitude | Relative power |
| --- | --- | --- | --- |
| 0 | Off | 0 | 0 |
| 1 | -18 dB | 0.1258925412 | 0.0158489319 |
| 2 | -12 dB | 0.2511886432 | 0.0630957344 |
| 3 | -6 dB | 0.5011872336 | 0.2511886432 |
| 4 | 0 dB | 1 | 1 |

The four active levels are 6 dB apart. Level zero remains exact silence for
the added layer; silence cannot be a finite decibel step. The chosen active
range is 18 dB, giving more useful spacing near the quiet end than the previous
0.25, 0.5, 0.75, 1 amplitude mapping.

Power ratios use `10*log10(P/Pmax)`; sample amplitudes use `20*log10(A/Amax)`.
Therefore the sample multiplier is `10^(dB/20)`, the square root of the power
ratio. See [TOA's decibel definitions](https://www.toa.eu/service/soundcheck/calculations-with-loudspeakers/).
These are relative layer gains, not absolute acoustic SPL. Equal decibel steps
do not promise identical perceived changes for every speaker, frequency band,
listener, or mixture with the fixed Brown bed.

## Continuity and headroom

One precomputed lookup is shared by live selection and startup/recovery, so
reopening the app applies the same saved grid level. Values remain clamped to
0...4. No logarithms, exponentiation, allocation, locks, or I/O were added to
the render callback. The existing 600 ms smoothstep still starts at the current
gain, including reversals and transitions to/from exact silence.

Brown always stays at level 4. All filters, source clocks, maximum gains,
background playback, recovery behavior, UI, colors, and saved coordinates are
unchanged. Only levels 1–3 of the added layers become quieter. No overall
normalization, compression, or limiting is used. The existing combined source
bound below 0.959 remains valid, including during transitions.

## Verification

- **29 core tests passed.** Actual emitted mid/high power was measured against
  the same sequence at full gain, both at startup and after live changes.
  Each active target and adjacent 6 dB step matched within 0.00001 dB; zero
  remained silent. Existing continuity, reversal, clamping, callback partition,
  persistence, and playback-state checks passed.
- **Five iOS-engine integration tests and one UI flow passed**, including all
  25 selections, background render-clock continuity, engine identity, pause,
  and saved selection. Result: `build/log-scale-v6/IntegrationAndUI.xcresult`.
- **34 Apple-engine offline renders passed**: all 25 cells at 48 kHz, the four
  corners at 44.1 kHz, rapid changes at both rates, slower transitions, and
  16/48 kHz mono output. No silent buffers, invalid samples, unequal stereo
  channels, or render retries occurred. Every 100 ms window passed the existing
  continuity threshold.
- Maximum estimated 8x intersample peak: **-13.10 dBFS**. No clipping occurred
  in these renders. Bass power variation across the 25 cells: **0.000011 dB**.
  Every upward/rightward step increased the corresponding measured band power.
- All four corners are **sample-for-sample identical to build 5** at 44.1 and
  48 kHz, including startup. This includes the original Brown and maximum mix.
- Filter/RNG algorithms are unchanged; earlier 48-hour accelerated source
  tests were not repeated for this gain-table correction. Real-device listening
  to the new scale and physical overnight playback remain unverified.

Measurements: [log-scale-measurements.json](log-scale-measurements.json).
Render comparisons: `build/log-scale-v6/corner-preservation.json`.
Package/source hashes: [build-6-manifest.json](build-6-manifest.json).
The original grid methods are in [SOUND_GRID_AUDIT.md](SOUND_GRID_AUDIT.md).

Run `swift test`, the existing Xcode test scheme, and the same render cases from
the grid audit. The analysis script now accepts an output directory:
`uv run --with numpy --with scipy --with matplotlib python scripts/check-grid.py build/log-scale-v6`.
