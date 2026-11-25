"""Exercise the production mix renderer through actual AVAudioEngine conversion.

Requires compiled build/loudness/render-engine (scripts/render-loudness.swift).
Temporary route WAVs are removed after independent peak analysis.
"""
from pathlib import Path
import argparse
import json
import subprocess
import warnings
import numpy as np
from scipy import signal
from scipy.io import wavfile

parser = argparse.ArgumentParser()
parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1] / "build/loudness")
args = parser.parse_args()
root = args.root.resolve()
cases = []
for rate in [8000, 16000, 24000, 32000, 44100, 48000, 88200, 96000, 192000]:
    for channels in [1, 2]: cases.append((rate, channels, "5,1,0", "stereo"))
for rate in [44100, 48000, 96000]:
    for mix in ["0,1,5", "3,3,2", "5,5,5", "1,0,5"]:
        for mode in ["mono", "rapid"]: cases.append((rate, 2, mix, mode))
results = []
for i, (rate, channels, mix, mode) in enumerate(cases):
    path = root / f"route-{i}.wav"
    subprocess.run([str(root/"render-engine"),str(rate),"12",mix,"3",str(channels),mode,str(path)],
                   check=True, capture_output=True)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", wavfile.WavFileWarning)
        r, x = wavfile.read(path)
    assert r == rate and len(x) == 12*rate
    if x.ndim == 1: x = x[:,None]
    true_peak = float(np.max(abs(signal.resample_poly(x.astype(float),16,1,axis=0,window=("kaiser",10)))))
    assert true_peak < 10**(-2/20), (rate, channels, mix, mode, true_peak)
    results.append(dict(rate=rate,channels=channels,mix=mix,mode=mode,
                        truePeak16x=true_peak,peak=float(abs(x).max())))
    path.unlink()
print(json.dumps({"passed":True,"renders":len(results),"maxTruePeak":max(r["truePeak16x"] for r in results)},indent=2))
(root/"apple-conversion.json").write_text(json.dumps(results,indent=2)+"\n")
