"""Compare build 30 with an independently compiled build-29 renderer.

Checks exact legacy PCM, an independent weighted-source composition for all
216 new mixes, and partition-independent commands involving the trace level.
"""
import argparse
import ctypes as C
import hashlib
import itertools
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--root", type=Path, default=ROOT / "build/mix-resolution")
args = parser.parse_args()
root = args.root.resolve()

class Renderer:
    def __init__(self, name):
        self.path = root / name
        self.lib = C.CDLL(str(self.path))
        for name, params, result in [
            ("BNMixCreate", [C.c_uint64], C.c_void_p),
            ("BNMixDestroy", [C.c_void_p], None),
            ("BNMixSetLevels", [C.c_void_p, C.c_int, C.c_int, C.c_int], None),
            ("BNMixSetOffsetDB", [C.c_void_p, C.c_int], None),
            ("BNMixSetStereo", [C.c_void_p, C.c_bool], None),
            ("BNMixBeginFadeIn", [C.c_void_p], None),
            ("BNMixRender", [C.c_void_p, C.c_void_p, C.c_void_p, C.c_uint32], None),
        ]:
            fn = getattr(self.lib, name); fn.argtypes = params; fn.restype = result

    def create(self, levels=None, offset=0):
        g = self.lib.BNMixCreate(478931267)
        assert g
        if levels is not None: self.lib.BNMixSetLevels(g, *levels)
        self.lib.BNMixSetOffsetDB(g, offset)
        self.lib.BNMixBeginFadeIn(g)
        return g

    def render(self, g, count):
        data = np.empty((2, count), dtype=np.float32)
        self.lib.BNMixRender(g, data[0].ctypes.data, data[1].ctypes.data, count)
        assert np.isfinite(data).all()
        return data

old, new = Renderer("libBaseline29.dylib"), Renderer("libMix.dylib")
def mapped(levels): return tuple(x + 1 if x else 0 for x in levels)

compared_frames = 0
# Include startup without explicit setters to verify the default migrated too.
a, b = old.create(), new.create()
assert np.array_equal(old.render(a, 96000), new.render(b, 96000))
compared_frames += 96000
old.lib.BNMixDestroy(a); new.lib.BNMixDestroy(b)
for offset in [-18, 0, 3]:
    for levels in itertools.product(range(5), repeat=3):
        a, b = old.create(levels, offset), new.create(mapped(levels), offset)
        assert np.array_equal(old.render(a, 48000), new.render(b, 48000)), (offset, levels)
        compared_frames += 48000
        old.lib.BNMixDestroy(a); new.lib.BNMixDestroy(b)

# Continuous changes must preserve both the source sequence and transition.
a, b = old.create(), new.create()
for index, levels in enumerate(itertools.product(range(5), repeat=3)):
    old.lib.BNMixSetLevels(a, *levels); new.lib.BNMixSetLevels(b, *mapped(levels))
    for renderer, pointer in [(old, a), (new, b)]:
        renderer.lib.BNMixSetStereo(pointer, index % 3 == 0)
        renderer.lib.BNMixSetOffsetDB(pointer, [-18, 0, 3][index % 3])
    assert np.array_equal(old.render(a, 8192), new.render(b, 8192)), levels
    compared_frames += 8192
old.lib.BNMixDestroy(a); new.lib.BNMixDestroy(b)

# During startup the slow correction is deliberately idle. Quiet-offset source
# renders avoid peak intervention; thus independent isolated sources predict the
# complete sample stream using K-weighted normalization and the requested dB.
count = 33000
isolated = []
for band in range(3):
    levels = [0, 0, 0]; levels[band] = 5
    g = new.create(levels, -18)
    isolated.append(new.render(g, count).astype(float))
    new.lib.BNMixDestroy(g)
powers = np.array(json.loads((ROOT / "Store/loudness-design-v2.json").read_text())["bandKPower"])
weights = np.array([0, 10**(-30/20), 10**(-18/20), 10**(-12/20), 10**(-6/20), 1])
max_error = 0.0
for levels in itertools.product(range(6), repeat=3):
    q = weights[list(levels)] * np.sqrt(powers)
    if np.any(q): q /= np.linalg.norm(q)
    expected = sum(q[i] * isolated[i] for i in range(3))
    g = new.create(levels, -18)
    actual = new.render(g, count)
    new.lib.BNMixDestroy(g)
    error = float(np.max(abs(actual - expected)))
    assert error < 1e-8, (levels, error)
    max_error = max(max_error, error)

# A trace-level render cannot depend on the system's arbitrary buffer size.
a, b = new.create((1, 5, 2)), new.create((1, 5, 2))
n = 192013
expected = new.render(a, n)
parts, done = [], 0
while done < n:
    frames = min(n-done, 1 + (done*37) % 2048)
    parts.append(new.render(b, frames)); done += frames
assert np.array_equal(expected, np.concatenate(parts, axis=1))
new.lib.BNMixDestroy(a); new.lib.BNMixDestroy(b)

result = {
    "passed": True, "legacyMixes": 125, "legacyOffsetsDB": [-18, 0, 3],
    "legacySamplesComparedPerChannel": compared_frames, "legacyPCMBitIdentical": True,
    "newMixesIndependentlyComposed": 216, "maximumCompositionError": max_error,
    "tracePartitionFrames": n, "tracePartitionBitIdentical": True,
    "relativeDB": [None, -30, -18, -12, -6, 0], "relativePower": (weights**2).tolist(),
    "librariesSHA256": {r.path.name: hashlib.sha256(r.path.read_bytes()).hexdigest() for r in [old, new]},
}
(root / "mix-resolution.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
