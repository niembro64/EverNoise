# Practical frequency tapers and household listening — build 28

High, Mid, Low now run from top to bottom on iOS and Apple TV, matching the
spectrogram. The five buttons, accessibility identities, saved mix, and default
Low/Mid/High indices 2/2/1 remain. The settings section **For the ones you care
for** describes a broad, adjustable blanket of sound for households with babies,
children and pets, with clear limits and caregiver guidance.

## Sound design

This intentionally changes timbre. **sound-baseline-build-27** preserves the
complete previous app at `815bc1d2a7516f88318d6803be617b4e45875601`.

- Common bass taper: fourth-order Butterworth high-pass at **30 Hz**, replacing
  the second-order 20 Hz filter. Two fixed biquads run continuously per source.
  Attenuation is about 94.09 dB at 2 Hz, 38.17 dB at 10 Hz, 14.25 dB at 20 Hz,
  3.01 dB at 30 Hz, and 0.41 dB at 40 Hz, relative to its passband.
- Common treble taper: second-order Butterworth low-pass at **20 kHz**, replacing
  18 kHz. Attenuation is about 0.70 dB at 18 kHz, 3.01 dB at 20 kHz, 12.59 dB at
  22 kHz, and 64.49 dB at 23.9 kHz. The source clock remains 48 kHz.
- Both complete edge responses are monotonic, without resonant boost. These
  are smooth filters with residual tails, not brick-wall frequency exclusions.
- Pink shelves and complementary 200 Hz / 2 kHz splits remain. The crossover
  powers still sum to one, within 4.65e-13 over 290,000 frequencies. Shared
  tapers do not disturb that identity.
- Band K-weighted power calibration and pre-normalization L1 bounds are
  regenerated in separate design-2 records. Design-1 records remain intact.
  Loudness targets, saved offset, slow correction, linked peak protection,
  transitions, source states, capture, and playback lifecycle are unchanged.
  The fixed filter bound alone does not describe the normalized output path.

The spectrogram retains its 2 Hz–48 kHz axis and fixed frequency colors. Faint
residual energy is still measured honestly; the source's 24 kHz boundary remains
marked. Its signal is captured before system volume, output conversion and
speaker processing. It is not a microphone or a sound-pressure meter.

## Measurements

- Compiled C impulse responses match the independently evaluated SciPy SOS
  responses exactly in this run. Adversarial bounded inputs and filter
  linearity checks pass. See [frequency measurements](frequency-tapers-v28.json).
- In a 60-second steady default render, final output power in 1–3 Hz falls
  **49.97 dB** versus build 27; 3–10 Hz falls **28.62 dB**, and 10–20 Hz falls
  **15.31 dB**. Power in 30–60 Hz changes by only **-0.35 dB**. At 18–20 kHz it
  rises **3.43 dB**. These are comparisons at the same normalized target, not
  speaker SPL measurements or guaranteed masking benefits.
- All 125 mixes at 0 and +3 dB offset pass: largest measured loudness error
  **0.0712 LU**, largest independently reconstructed 16x peak **0.655698**.
  Rapid controls, silence, pause/resume, mono identity, and offset checks pass.
- Overload stress reaches at most **0.707938** after independent reconstruction;
  below-threshold sine passthrough is exactly a delay. The sample ceiling stays
  -3 dBFS, with a post-conversion acceptance limit of -2 dBTP.
- **36 AVAudioEngine conversions** at 8–192 kHz, one/two channels, Mono/Stereo
  and rapid changes pass; largest reconstructed peak **0.575397**.
- Undefined-behavior/bounds sanitizers pass for 72 seconds of renderer stress
  and the separate overload harness. No AddressSanitizer result is claimed.
- **52 core, 33 iOS integration and 10 tvOS integration tests** pass. Affected
  iPhone/iPad/TV UI flows cover row order, selected settings, Max/Off, pause,
  settings persistence and continued audio. Final family copy is readable in
  the iPad settings sheet; final phone verification is recorded with the build.
- Independent FFT/decimation checks pass. Relative PSD error is at most
  1.01e-7; visible row error is below 0.000569 dB. The new quiet sub-bass exposes
  up to 0.00232 dB single-precision error below the display's -120 dBFS/Hz floor.
  The audit reports this raw error, checks row mapping separately (7.14e-6 dB),
  and retains the global linear-power and Parseval checks. Production analysis
  and the visual floor did not change to conceal the residual.

Extended continuity qualification and delivery are recorded in the final build
audit and delivery files. No physical-speaker listening, Bluetooth recording,
overnight hardware test, or child/animal efficacy study was performed here.
Software peak margin does not establish a safe acoustic listening level.

## Wording and evidence

Children can retain upper-frequency sensitivity adults no longer notice;
infant hearing is still developing, so the app does not claim every baby has a
universally wider range. The upper edge preserves the conventional upper human
audible range without adding a separate ultrasonic source. Dogs and cats can
hear above that range; the copy explicitly says the app cannot cover everything
they hear. Output also depends on the actual speaker and connection.

- [Trehub et al., auditory sensitivity in school-age children](https://pubmed.ncbi.nlm.nih.gov/3171476/)
  describes development and age-related differences, including near 20 kHz.
- [American Academy of Pediatrics, 2023 noise-exposure policy](https://doi.org/10.1542/peds.2023-063752)
  supports low volume, distance and limited duration if infant sound machines
  are used. Settings links to this guidance and explains that a caregiver must
  stop playback because the app has no automatic deadline.
- [LSU veterinary hearing-range reference](https://www.lsu.edu/vetmed/deafness/hearingrange.php)
  explains measurement and species differences. No full-range pet coverage or
  guaranteed calming, masking or sleep benefit is promised.
- [Cornell veterinary guidance on sound sensitivity](https://www.vet.cornell.edu/departments-centers-and-institutes/riney-canine-health-center/canine-health-topics/anxious-behavior-how-help-your-dog-cope-unsettling-situations)
  informs the practical advice to observe pets and allow a quiet retreat.

## Reproduce

Run `scripts/design-complementary.py` and `scripts/design-loudness.py` to verify
the generated headers. Compile the production renderer and the tagged build-27
renderer into separate libraries. Run `complementary-filter-audit.c`, then
`check-frequency-tapers.py build/family-spectrum`. Use `check-loudness.py` with
`--library` and `--output`, and `check-loudness-conversion.py --root` with a newly
compiled `render-loudness.swift` executable. Run the existing core, integration
and affected UI tests. The exact source and signed package hashes are retained
in `build-28-manifest.json`.
