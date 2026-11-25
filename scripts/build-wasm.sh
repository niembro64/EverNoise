#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
compiler="${EMCC:-$repo/tools/emsdk/upstream/emscripten/emcc}"
mkdir -p "$repo/web/src/wasm"
common=(-O3 -ffp-contract=off -s MODULARIZE=1 -s EXPORT_ES6=1 -s ENVIRONMENT=web,worker,node -s ALLOW_MEMORY_GROWTH=0 -s INITIAL_MEMORY=33554432 -s FILESYSTEM=0 -s EXPORTED_RUNTIME_METHODS=HEAPF32 -s MALLOC=emmalloc)
"$compiler" "${common[@]}" -I"$repo/shared/dsp/include" "$repo/shared/dsp/BNMixRenderer.c" "$repo/shared/web-audio.c" \
  -s 'EXPORTED_FUNCTIONS=["_ENAudioCreate","_ENAudioDestroy","_ENAudioConfigure","_ENAudioPlay","_ENAudioSilent","_ENAudioRender","_ENAudioLeft","_ENAudioRight","_ENAudioFrames"]' \
  -o "$repo/web/src/wasm/audio.js"
"$compiler" "${common[@]}" -I"$repo/shared/analysis/include" "$repo/shared/analysis/BNSpectrum.c" "$repo/shared/web-spectrum.c" \
  -s 'EXPORTED_FUNCTIONS=["_ENSpectrumCreate","_ENSpectrumDestroy","_ENSpectrumInput","_ENSpectrumColumns","_ENSpectrumConsume"]' \
  -o "$repo/web/src/wasm/spectrum.js"
