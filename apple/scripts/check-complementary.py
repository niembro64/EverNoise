"""Exercise all new mixes and actual Apple output conversion. Deletes transient WAVs.

Usage: python3 scripts/check-complementary.py build/release-v23
       --baseline-renderer build/release-v22/spectrum/render-stereo
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse, hashlib, json, subprocess, warnings
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

parser = argparse.ArgumentParser()
parser.add_argument("root", type=Path)
parser.add_argument("--baseline-renderer", type=Path, required=True)
args = parser.parse_args()
root = args.root
folder = root / "engine"; folder.mkdir(exist_ok=True)
warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)


def render(name, rate, seconds, mix, channels=2, mode="stereo", family="complementary", old=False):
    path = folder / (name + ".wav")
    command = [str(args.baseline_renderer if old else root/"render-stereo"), str(rate),
               str(seconds), mix, str(path), str(channels), mode]
    if not old: command.append(family)
    result = subprocess.run(command, capture_output=True, text=True)
    (folder/(name+".log")).write_text(result.stdout+result.stderr)
    assert result.returncode == 0, (name, result.stdout, result.stderr)
    actual_rate, data = wavfile.read(path)
    assert actual_rate == rate and len(data) == rate*seconds and np.isfinite(data).all()
    if data.ndim == 1: data = data[:,None]
    stable = data[rate:].astype(np.float64)
    peak = float(np.max(np.abs(resample_poly(stable,4,1,axis=0))))
    assert peak < .95, (name, peak)
    metadata = json.loads(Path(str(path)+".json").read_text())
    assert metadata["renderRetries"] == 0, (name, metadata)
    if family == "complementary": assert len(set(metadata["sourceFrames"])) == 1
    silent = mix == "0,0,0"
    if silent: assert np.all(data == 0)
    elif mix not in ["rapid","mute"]: assert metadata["silentBlocks"] == [0]*channels
    correlation, mismatch = None, None
    if channels == 2 and mode == "mono": assert np.array_equal(data[:,0],data[:,1])
    if channels == 2 and mode == "stereo" and not silent:
        correlation = float(np.corrcoef(stable.T)[0,1])
        powers = np.mean(stable*stable,axis=0)
        mismatch = abs(float(10*np.log10(powers[0]/powers[1])))
        assert abs(correlation)<.15 and mismatch<.8, (name,correlation,mismatch)
    record = {"name":name,"sampleRate":rate,"seconds":seconds,"mix":mix,
              "channels":channels,"mode":mode,"family":family,
              "estimatedIntersamplePeak":peak,"rms":np.sqrt(np.mean(stable*stable,axis=0)).tolist(),
              "correlation":correlation,"leftRightPowerDifferenceDB":mismatch,
              "renderRetries":metadata["renderRetries"],"sourceFrames":metadata["sourceFrames"],
              "wavSHA256":hashlib.sha256(path.read_bytes()).hexdigest()}
    return data, record, path


records, references = [], []
for code in ["400","040","004"]:
    data, record, path = render("mix-"+code,48000,4,",".join(code))
    references.append(data.astype(np.float64)); records.append(record)
gains = [0,10**(-18/20),10**(-12/20),10**(-6/20),1]


def check_mix(levels):
    code = "".join(map(str,levels))
    data, record, path = render("mix-"+code,48000,4,",".join(map(str,levels)))
    expected = sum(x*gains[level] for x,level in zip(references,levels))
    error = float(np.max(abs(data-expected)))
    assert error < 1e-7, (code,error)
    record["sampleSumMaximumError"] = error
    path.unlink()
    return record


mixes = [(l,m,h) for l in range(5) for m in range(5) for h in range(5)
         if (l,m,h) not in [(4,0,0),(0,4,0),(0,0,4)]]
with ThreadPoolExecutor(max_workers=3) as pool:
    for i, record in enumerate(pool.map(check_mix,mixes)):
        records.append(record)
        if i%25 == 24: print(f"Checked {i+4}/125 mixes",flush=True)
print("All 125 balances match the weighted source sum; checking output routes.",flush=True)


def route(job):
    rate, channels, mode = job
    data, record, path = render(f"route-{rate}-{channels}-{mode}",rate,12,"4,4,4",channels,mode)
    path.unlink(); return record


jobs = [(r,c,m) for r in [16000,44100,48000,96000] for c in [1,2]
        for m in ["mono","stereo","switch","rapid"]]
with ThreadPoolExecutor(max_workers=3) as pool: records.extend(pool.map(route,jobs))
for mix,mode in [("rapid","rapid"),("mute","stereo")]:
    data, record, path = render("transition-"+mix,48000,15,mix,2,mode)
    if mix == "mute":
        assert np.max(abs(data[int(3.5*48000):int(4.5*48000)])) == 0
        assert np.max(abs(data[int(6*48000):int(7*48000)])) > .001
    records.append(record); path.unlink()

# The legacy API is retained for a truthful rollback and comparison.
legacy = []
for rate in [44100,48000]:
    for mode in ["mono","stereo"]:
        old, _, oldpath = render(f"legacy-old-{rate}-{mode}",rate,4,"2,2,1",2,mode,"legacy",True)
        new, record, newpath = render(f"legacy-new-{rate}-{mode}",rate,4,"2,2,1",2,mode,"legacy")
        assert np.array_equal(old,new), (rate,mode)
        legacy.append({"rate":rate,"mode":mode,"bitIdenticalToBuild22":True})
        oldpath.unlink(); newpath.unlink()

spectra = [("spectrum-low","4,0,0"),("spectrum-mid","0,4,0"),("spectrum-high","0,0,4"),
           ("spectrum-equal","4,4,4"),("spectrum-default","2,2,1")]
with ThreadPoolExecutor(max_workers=3) as pool:
    for data,record,path in pool.map(lambda job:render(job[0],48000,65,job[1]),spectra): records.append(record)
_, record, _ = render("spectrum-legacy-default",48000,65,"2,2,1",family="legacy")
records.append(record)
report = {"complementaryEngineRendersPassed":165,"legacyComparisonRendersPassed":8,
          "legacySpectrumRendersPassed":1,"all125MixesPassed":True,"routeRendersPassed":32,
          "legacyWaveformComparisons":legacy,"renders":records,
          "maxEstimatedIntersamplePeak":max(r["estimatedIntersamplePeak"] for r in records if r["family"]=="complementary"),
          "maxWeightedSampleSumError":max(r.get("sampleSumMaximumError",0) for r in records),
          "scriptSHA256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
# 125 static + 32 routes + 2 transition + 5 spectrum = 164 new-engine renders.
report["complementaryEngineRendersPassed"] = sum(r["family"]=="complementary" for r in records)
assert report["complementaryEngineRendersPassed"] == 164
(root/"engine-analysis.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps({k:v for k,v in report.items() if k!="renders"},indent=2))
