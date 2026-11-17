"""Verify compiled filter impulses and final PCM against the build-27 baseline.

Run the C complementary-filter-audit into ROOT/impulses.f64 first. ROOT must
contain libNoiseLoudness.dylib and libBaseline.dylib built from the tagged source.
No audio device or microphone is involved; these are digital measurements.
"""
import argparse
import ctypes as C
import json
from pathlib import Path
import numpy as np
from scipy import signal

parser = argparse.ArgumentParser()
parser.add_argument("root", type=Path)
args = parser.parse_args()
root = args.root.resolve()
repo = Path(__file__).resolve().parents[1]
design = json.loads((repo / "Store/complementary-design-v2.json").read_text())
impulses = np.fromfile(root / "impulses.f64", dtype=np.float64).reshape(4, -1)
impulse = np.zeros(impulses.shape[1]); impulse[0] = 1
errors = []
for band in range(4):
    sos = design["commonSOS"] if band == 3 else np.vstack([design["commonSOS"], design["crossoverSOS"][band]])
    expected = signal.sosfilt(sos, impulse) * design["commonGain"]
    errors.append(float(np.max(abs(impulses[band] - expected))))
assert max(errors) < 1e-12, errors

# Independent response checks enforce the intended shape, not just agreement
# between a generated header and its own JSON. Each edge must be monotonic.
low_f = np.array([2, 10, 15, 20, 30, 40, 60, 100.0])
hp = np.array(design["commonSOS"][:2])
low_db = 20*np.log10(abs(signal.sosfreqz(hp, worN=low_f, fs=48000)[1]))
assert low_db[0] < -94 and low_db[1] < -38 and low_db[3] < -14
assert abs(low_db[4]+3.0103) < .001 and low_db[5] > -.42
high_f = np.array([10000, 16000, 18000, 20000, 22000, 23000, 23900.0])
lp = np.array(design["commonSOS"][-1:])
high_db = 20*np.log10(abs(signal.sosfreqz(lp, worN=high_f, fs=48000)[1]))
assert high_db[2] > -.8 and abs(high_db[3]+3.0103) < .001 and high_db[-1] < -64
grid = np.geomspace(1, 23999, 100000)
h = abs(signal.sosfreqz(hp, worN=grid, fs=48000)[1])
l = abs(signal.sosfreqz(lp, worN=grid, fs=48000)[1])
assert np.all(np.diff(h) >= -1e-9) and np.max(h) <= 1+1e-9
assert np.all(np.diff(l) <= 1e-9) and np.max(l) <= 1+1e-9

def renderer(path):
    lib = C.CDLL(str(path))
    for name, types, result in [
        ("BNMixCreate", [C.c_uint64], C.c_void_p),
        ("BNMixDestroy", [C.c_void_p], None),
        ("BNMixSetLevels", [C.c_void_p, C.c_int, C.c_int, C.c_int], None),
        ("BNMixBeginFadeIn", [C.c_void_p], None),
        ("BNMixRender", [C.c_void_p, C.c_void_p, C.c_void_p, C.c_uint32], None),
    ]:
        fn = getattr(lib, name); fn.argtypes = types; fn.restype = result
    return lib

def spectrum(lib, levels):
    g = lib.BNMixCreate(59729523)
    try:
        lib.BNMixSetLevels(g, *levels); lib.BNMixBeginFadeIn(g)
        pcm = np.empty((2, 65*48000), dtype=np.float32)
        lib.BNMixRender(g, pcm[0].ctypes.data, pcm[1].ctypes.data, pcm.shape[1])
        assert np.isfinite(pcm).all() and np.max(abs(pcm)) < .708
        f, density = signal.welch(pcm[:,5*48000:].astype(float), fs=48000,
                                  nperseg=524288, noverlap=262144, axis=1)
        return f, np.mean(density, axis=0)
    finally:
        lib.BNMixDestroy(g)

old, new = renderer(root / "libBaseline.dylib"), renderer(root / "libNoiseLoudness.dylib")
cases = []
for name, levels in [("default", (2,2,1)), ("bass-only", (4,0,0)), ("high-only", (0,0,4))]:
    f, before = spectrum(old, levels)
    _, after = spectrum(new, levels)
    bands = []
    for lower, upper in [(1,3), (3,10), (10,20), (30,60), (100,200), (16000,18000), (18000,20000), (20000,22000)]:
        region = (f >= lower) & (f < upper)
        b, a = np.sum(before[region])*(f[1]-f[0]), np.sum(after[region])*(f[1]-f[0])
        bands.append({"Hz": [lower,upper], "beforeDBFS": float(10*np.log10(b)),
                      "afterDBFS": float(10*np.log10(a)), "changeDB": float(10*np.log10(a/b))})
    if name in ["default", "bass-only"]:
        assert bands[0]["changeDB"] < -45, bands[0]
        assert bands[1]["changeDB"] < -25, bands[1]
    if name == "high-only": assert bands[-2]["changeDB"] > 1.5
    cases.append({"case": name, "levels": levels, "bands": bands})

record = {"passed": True, "compiledImpulseMaxError": max(errors),
          "highPassResponseDB": dict(zip(map(str, low_f), low_db)),
          "lowPassResponseDB": dict(zip(map(str, high_f), high_db)),
          "noEdgeResonantBoost": True, "finalOutputComparisons": cases,
          "baselineTag": "sound-baseline-build-27", "digitalMeasurementOnly": True}
(root / "frequency-tapers.json").write_text(json.dumps(record, indent=2)+"\n")
print(json.dumps(record, indent=2))
