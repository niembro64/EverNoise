#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
if [[ "$(uname)" == Darwin ]]; then
  common=(-O3 -ffp-contract=off -Ishared/dsp/include -Ishared/analysis/include shared/tests/reference.c shared/dsp/BNMixRenderer.c shared/analysis/BNSpectrum.c)
  clang "${common[@]}" -framework Accelerate -o artifacts/reference-apple
  clang "${common[@]}" -DBN_FORCE_PORTABLE_ANALYSIS -o artifacts/reference-portable
  artifacts/reference-apple artifacts/pcm-apple.f32 artifacts/spectrum-apple.f32
  artifacts/reference-portable artifacts/pcm-portable.f32 artifacts/spectrum-portable.f32
  python3 scripts/check-fft-parity.py
fi
node --test web/tests/*.test.mjs
