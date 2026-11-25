import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  normalize,
  DEFAULTS,
  load,
  power,
  decode,
  encode,
} from "../src/state.js";
import createAudio from "../src/wasm/audio.js";
import createSpectrum from "../src/wasm/spectrum.js";
test("saved preferences recover from corrupt data without loud surprises", () => {
  assert.deepEqual(
    load({
      getItem() {
        return "{broken";
      },
    }),
    DEFAULTS,
  );
  assert.deepEqual(normalize(null), DEFAULTS);
  assert.equal(normalize({ offset: 99 }).offset, 3);
  assert.equal(normalize({ offset: -99 }).offset, -18);
  assert.equal(normalize({ high: NaN }).high, 2);
  assert.equal(power(0), 0);
  assert.ok(power(1) < 0.002);
  for (let i = 0; i <= 100; i++)
    assert.ok(Math.abs(encode(decode(i / 100)) - i / 100) < 1e-12);
});
test("Wasm PCM is finite, independent stereo, and continuously faded", async () => {
  const m = await createAudio({
    wasmBinary: readFileSync(
      new URL("../src/wasm/audio.wasm", import.meta.url),
    ),
  });
  const a = m._ENAudioCreate(12345);
  m._ENAudioConfigure(a, 3, 3, 2, 1, 0);
  m._ENAudioPlay(a, 1);
  const l = m._ENAudioLeft(a) / 4,
    r = m._ENAudioRight(a) / 4;
  let peak = 0,
    ll = 0,
    rr = 0,
    lr = 0;
  for (let n = 0; n < 500; n++) {
    m._ENAudioRender(a, 1024);
    for (let i = 0; i < 1024; i++) {
      const x = m.HEAPF32[l + i],
        y = m.HEAPF32[r + i];
      assert.ok(Number.isFinite(x) && Number.isFinite(y));
      peak = Math.max(peak, Math.abs(x), Math.abs(y));
      ll += x * x;
      rr += y * y;
      lr += x * y;
    }
  }
  assert.ok(peak > 0 && peak < 0.9);
  assert.ok(Math.abs(lr / Math.sqrt(ll * rr)) < 0.1);
  assert.equal(m._ENAudioFrames(a), 512000);
  m._ENAudioPlay(a, 0);
  for (let n = 0; n < 100; n++) m._ENAudioRender(a, 1024);
  assert.ok(m._ENAudioSilent(a));
  assert.equal(m.HEAPF32[l + 1023], 0);
  m._ENAudioDestroy(a);
});
test("portable spectral analysis resolves 1000 Hz and leaves ultrasonic region empty", async () => {
  const m = await createSpectrum({
    wasmBinary: readFileSync(
      new URL("../src/wasm/spectrum.wasm", import.meta.url),
    ),
  });
  const s = m._ENSpectrumCreate();
  assert.ok(s);
  const input = m._ENSpectrumInput(s) / 4,
    output = m._ENSpectrumColumns(s) / 4;
  let frame = 0,
    last,
    total = 0;
  const start = performance.now();
  for (let block = 0; block < 140; block++) {
    for (let i = 0; i < 4096; i++) {
      const x = 0.1 * Math.sin((2 * Math.PI * 1000 * (frame + i)) / 48000);
      m.HEAPF32[input + 2 * i] = x;
      m.HEAPF32[input + 2 * i + 1] = x;
    }
    const count = m._ENSpectrumConsume(s, 4096, frame);
    if (count) {
      last = m.HEAPF32.slice(
        output + (count - 1) * 1024,
        output + count * 1024,
      );
      total += count;
    }
    frame += 4096;
  }
  let max = 0;
  for (let i = 0; i < 1024; i++) {
    if (2 * 24000 ** (i / 1023) > 24000) assert.ok(Number.isNaN(last[i]));
    else assert.ok(Number.isFinite(last[i]));
    if (last[i] > last[max]) max = i;
  }
  const hz = 2 * 24000 ** (max / 1023);
  assert.ok(Math.abs(hz - 1000) < 50, `peak ${hz}`);
  console.log(
    JSON.stringify({
      analysisSeconds: (performance.now() - start) / 1000,
      audioSeconds: frame / 48000,
      columns: total,
      peakHz: hz,
    }),
  );
  m._ENSpectrumDestroy(s);
});

test("Wasm output matches the native Apple reference at the same seed", async (t) => {
  let ref;
  try {
    ref = new Float32Array(
      readFileSync(
        new URL("../../artifacts/pcm-apple.f32", import.meta.url),
      ).buffer,
    );
  } catch {
    t.skip("Run scripts/test-ports.sh to create native fixture");
    return;
  }
  const bytes = readFileSync(
    new URL("../../artifacts/pcm-apple.f32", import.meta.url),
  );
  ref = new Float32Array(bytes.buffer, bytes.byteOffset, bytes.byteLength / 4);
  const m = await createAudio({
    wasmBinary: readFileSync(
      new URL("../src/wasm/audio.wasm", import.meta.url),
    ),
  });
  const a = m._ENAudioCreate(12345);
  m._ENAudioConfigure(a, 3, 3, 2, 1, 0);
  m._ENAudioPlay(a, 1);
  const l = m._ENAudioLeft(a) / 4,
    r = m._ENAudioRight(a) / 4;
  let difference = 0;
  for (let n = 0; n < 200; n++) {
    m._ENAudioRender(a, 1024);
    for (let i = 0; i < 1024; i++) {
      difference = Math.max(
        difference,
        Math.abs(m.HEAPF32[l + i] - ref[n * 2048 + i * 2]),
        Math.abs(m.HEAPF32[r + i] - ref[n * 2048 + i * 2 + 1]),
      );
    }
  }
  assert.ok(difference < 1e-6, `PCM mismatch ${difference}`);
  console.log(JSON.stringify({ wasmNativeMaxSampleDifference: difference }));
  m._ENAudioDestroy(a);
});
