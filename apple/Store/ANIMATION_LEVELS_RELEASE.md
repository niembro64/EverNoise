# Three animation levels — build 19

Settings now uses a native segmented Animations picker with Low, Med, and High.

| Level | Infinity | Background ribbons |
| --- | --- | --- |
| Low | Still | Hidden |
| Med (default) | Animated while sound plays | Hidden |
| High | Animated while sound plays | Animated |

The app stores the choice under `animationLevel`. Fresh installations and the previous On setting start on Med. A saved previous Off becomes Low; valid new selections always take precedence over the obsolete boolean. Invalid new values fall back through the same migration. All three choices persist across reopening.

`AnimationLevel` supplies the shared policy to Settings, controls, `RibbonScene`, and `FluidMotion`. Low settles the current frame and stops scheduled animation updates. Med and High use the existing continuous clock; adding/removing background ribbons retargets their opacity smoothly without resetting the infinity phase. Med and Low settle background opacity to exactly zero, so the unchanged shader skips the backdrop. Reduce Motion and hidden-screen suspension are retained. Paused/all-off colors remain grayscale.

The ten audio/DSP/lifecycle sources are byte-identical to build 18, as is the signed package's compiled Metal library. The animation preference does not call the audio service. The existing build-18 color, spatial-seam, and GPU motion audits remain the shader baseline; they are not presented as new build-19 measurements.

Validation covers fresh defaults, legacy migration, all saved levels, continuous High/Med transitions, Low static color updates, Reduce Motion, and actual screenshot differences. The UI test checks visible infinity motion with zero ribbon pixels in Med, visible background ribbons in High, exact stillness in Low, all three saved choices across relaunch, and continued render counters without an audio-engine restart. All 26 tests (22 integration and four UI) passed in one complete run with no reruns. The Settings picker was visually inspected with each of its three selections. Final delivery is tracked separately in `RELEASE_STATUS.md` and `build-19-manifest.json`.

Physical-device battery savings and overnight listening are not measured by these simulator checks.

Final Release phone and tablet previews were captured after fresh simulator installations, without an animation override: both show the Med default with a flowing infinity and plain black background. Settings was inspected in all three states. Strict signing, distribution entitlements, background audio, compiled Metal, infinity icons, and source/package hashes pass. All 12 live support assets match source and 177 unrelated files were preserved.

Upload succeeded at 19:53:02 CST on November 14. Apple confirmed build 19 is ready in TestFlight at 19:54:32 CST. The public submission and portal notes/screenshots remain pending browser access. Fresh Release preferences on both phone and tablet were also read after shutdown: each persisted `med`, with no legacy boolean present.
