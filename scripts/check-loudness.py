"""Independent numerical checks of the actual production C renderer.

Build build/libNoiseLoudness.dylib from BNMixRenderer.c, then run this script.
All 125 mixes at default and maximum offsets, 16x reconstructed peaks,
K-weighted loudness, smooth commands, silence, mono, and rare-peak protection.
"""
import ctypes as C
import argparse
import importlib.util
import itertools
import json
from pathlib import Path
import time
import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=ROOT / "build/loudness")
parser.add_argument("--library", type=Path, default=ROOT / "build/libNoiseLoudness.dylib")
args = parser.parse_args()
OUT = args.output
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location("design", ROOT / "scripts/design-loudness.py")
design = importlib.util.module_from_spec(spec); spec.loader.exec_module(design)
K = design.K_SOS
lib = C.CDLL(str(args.library.resolve()))
pointer = C.c_void_p
class Metrics(C.Structure):
    _fields_ = [("power", C.c_double), ("slow", C.c_double), ("protection", C.c_double), ("frames", C.c_uint64)]
for name, args, result in [
    ("BNMixCreate", [C.c_uint64], pointer), ("BNMixDestroy", [pointer], None),
    ("BNMixSetLevels", [pointer, C.c_int, C.c_int, C.c_int], None),
    ("BNMixSetOffsetDB", [pointer, C.c_int], None), ("BNMixSetStereo", [pointer, C.c_bool], None),
    ("BNMixSetPlaying", [pointer, C.c_bool], None), ("BNMixBeginFadeIn", [pointer], None),
    ("BNMixRender", [pointer, pointer, pointer, C.c_uint32], None),
    ("BNMixReadMetrics", [pointer], Metrics),
]:
    fn = getattr(lib, name); fn.argtypes = args; fn.restype = result

def render(g, seconds):
    x = np.empty((2, round(48000*seconds)), dtype=np.float32)
    lib.BNMixRender(g, x[0].ctypes.data, x[1].ctypes.data, x.shape[1])
    assert np.isfinite(x).all()
    return x

def analyze(x, trim=1):
    weighted = signal.sosfilt(K, x, axis=1)[:, round(trim*48000):]
    power = np.mean(weighted**2, axis=1)
    true_peak = float(np.max(abs(signal.resample_poly(x, 16, 1, axis=1, window=("kaiser", 10)))))
    return {"LUFS": float(-.691+10*np.log10(sum(power))) if sum(power) else None,
            "peak": float(np.max(abs(x))), "truePeak16x": true_peak,
            "rms": np.sqrt(np.mean(x[:, round(trim*48000):].astype(float)**2, axis=1)).tolist()}

start = time.monotonic(); results = []
for offset, levels in itertools.product([0, 3], itertools.product(range(5), repeat=3)):
    g = lib.BNMixCreate(987654123)
    lib.BNMixSetLevels(g, *levels); lib.BNMixSetOffsetDB(g, offset); lib.BNMixBeginFadeIn(g)
    x = render(g, 10); m = lib.BNMixReadMetrics(g); lib.BNMixDestroy(g)
    result = {"levels": levels, "offsetDB": offset, **analyze(x), "finalProtectionGain": m.protection}
    if any(levels):
        assert abs(result["LUFS"] - (-20+offset)) < .65, result
        assert min(result["rms"]) > .01
    else:
        assert np.max(abs(x)) == 0
    assert result["truePeak16x"] <= 10**(-2/20), result
    results.append(result)
    if len(results)%50 == 0: print(f"Checked {len(results)}/250 mixes", flush=True)

# Recorded examples and offset, mono, and all-off behavior.
from scipy.io import wavfile
for name, levels, offset, stereo in [("default",(2,2,1),0,True), ("default-quiet",(2,2,1),-6,True),
                                    ("bass-max",(4,0,0),3,True), ("mono",(2,2,1),0,False)]:
    g = lib.BNMixCreate(123456789)
    lib.BNMixSetLevels(g,*levels); lib.BNMixSetOffsetDB(g,offset); lib.BNMixSetStereo(g,stereo)
    lib.BNMixBeginFadeIn(g); x = render(g,60)
    if not stereo: assert np.array_equal(x[0],x[1])
    wavfile.write(OUT/f"{name}.wav", 48000, x.T)
    result={"case":name, **analyze(x), "finalSlowGain":lib.BNMixReadMetrics(g).slow}
    assert result["truePeak16x"] < 10**(-2/20)
    results.append(result); lib.BNMixDestroy(g)

# Change all controls repeatedly without restarting; then silence, pause/resume.
g=lib.BNMixCreate(372893); parts=[render(g,2)]
for n in range(125):
    lib.BNMixSetLevels(g,n//25,(n//5)%5,n%5)
    lib.BNMixSetOffsetDB(g,3 if n%2 else -18); lib.BNMixSetStereo(g,bool(n%3))
    parts.append(render(g,.037))
lib.BNMixSetLevels(g,0,0,0); muted=render(g,2); assert np.max(abs(muted[:,48000:])) == 0
parts.append(muted); lib.BNMixSetLevels(g,2,2,1); parts.append(render(g,4))
lib.BNMixSetPlaying(g,False); muted=render(g,1); assert np.max(abs(muted[:,4800:])) == 0
parts.append(muted); lib.BNMixSetPlaying(g,True); parts.append(render(g,4)); lib.BNMixDestroy(g)
x=np.concatenate(parts,axis=1); result={"case":"rapid-controls-pause-silence",**analyze(x)}
assert result["truePeak16x"] < 10**(-2/20); results.append(result)
wavfile.write(OUT/"transitions.wav",48000,x.T)

adversarial=np.fromfile(OUT/"adversarial.f32",dtype=np.float32).reshape(-1,2).T
peak=analyze(adversarial)["truePeak16x"]
assert peak < 10**(-2/20), peak
record={"passed":True,"cases":results,"adversarialTruePeak16x":peak,
        "maximumTruePeak16x":max(x["truePeak16x"] for x in results),
        "maxMixLoudnessErrorLU":max(abs(x["LUFS"]-(-20+x["offsetDB"])) for x in results if x.get("LUFS") and "offsetDB" in x),
        "wallSeconds":time.monotonic()-start}
(OUT/"audit.json").write_text(json.dumps(record,indent=2)+"\n")
print(json.dumps({k:v for k,v in record.items() if k!="cases"},indent=2))
