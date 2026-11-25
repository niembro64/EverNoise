# Shared sound engine

`dsp/` is the production C engine used by Apple, Android (JNI), and the web (WebAssembly). The Apple AudioBufferList adapters are compiled only on Apple platforms. The numeric rendering algorithm is shared unchanged.

48 kHz source; independent stereo; complementary 200 Hz / 2 kHz crossovers; 30 Hz / 20 kHz edge tapers; six relative mix strengths; slow loudness correction and linked lookahead true-peak protection. No loops, network stream, or playback timer. See `apple/Store/SOUND_ENGINE_HISTORY.md` for sound history.
