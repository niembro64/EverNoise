"""Analyze actual Apple-mixer output for the three presets and transitions."""
import json
import warnings
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

root = Path("build/noise-options")
results, curves = {}, {}
warnings.simplefilter("ignore", wavfile.WavFileWarning)
for path in sorted(root.glob("*.wav")):
    rate, data = wavfile.read(path)
    if data.ndim == 2:
        assert np.array_equal(data[:, 0], data[:, 1]), path
        data = data[:, 0]
    x = data[rate:].astype(np.float64)
    assert np.isfinite(x).all()
    peak = float(np.max(np.abs(signal.resample_poly(x, 8, 1))))
    f, p = signal.welch(x, rate, nperseg=int(rate * 2), detrend=False)
    stats = json.loads(Path(str(path) + ".json").read_text())
    stats["true_peak_8x"] = peak
    stats["true_peak_dBFS"] = float(20*np.log10(peak))
    stats["dc_mean"] = float(np.mean(x))
    assert peak < .30, (path, peak)
    assert abs(stats["dc_mean"]) < .001
    assert stats["silent_blocks"] == 0 and stats["min_block_rms"] > .002
    if path.stem == "white-48000":
        centers = np.array([125, 250, 500, 1000, 2000, 4000, 8000, 16000])
        levels = [10*np.log10(p[(f>=c/1.1)&(f<c*1.1)].mean()) for c in centers]
        slope = float(np.polyfit(np.log2(centers), levels, 1)[0])
        stats["slope_dB_per_octave"] = slope
        assert abs(slope) < .3
    if path.stem == "gray-48000":
        mid = float(p[(f>=2500)&(f<3500)].mean())
        bass = float(p[(f>=125)&(f<250)].mean())
        air = float(p[(f>=6000)&(f<10000)].mean())
        stats["bass_vs_mid_density_dB"] = float(10*np.log10(bass/mid))
        stats["air_vs_mid_density_dB"] = float(10*np.log10(air/mid))
        stats["energy_below_500Hz_percent"] = float(p[f<500].sum()/p.sum()*100)
        assert stats["bass_vs_mid_density_dB"] > 20
        assert stats["air_vs_mid_density_dB"] > 2
        assert stats["energy_below_500Hz_percent"] > 75
    if path.stem in ["brown-48000", "brown-44100"]:
        reference = Path(f"build/audio-audit-v2/engine-{rate}.wav")
        _, baseline = wavfile.read(reference)
        stats["matches_approved_brown_output_exactly"] = bool(np.array_equal(data, baseline[:, 0]))
        assert stats["matches_approved_brown_output_exactly"], path
    if path.stem in ["brown-48000", "white-48000", "gray-48000"]:
        curves[path.stem.split("-")[0]] = (f, p)
    results[path.stem] = stats
    print(f"{path.stem}: RMS={stats['rms']:.6f}, 8x peak={peak:.6f}, silent blocks={stats['silent_blocks']}, transitions={stats['transitions']}")

fig, ax = plt.subplots(figsize=(9, 5), constrained_layout=True)
for mode, color in [("white", "#78838b"), ("brown", "#9d6d46"), ("gray", "#207e79")]:
    f, p = curves[mode]
    ax.semilogx(f[1:], 10*np.log10(np.maximum(p[1:], 1e-20)), label=mode.title(), color=color, linewidth=1.2)
ax.set(xlim=(20, 20000), ylim=(-110, -40), xlabel="Frequency (Hz)", ylabel="Power density (dBFS/Hz)", title="App output: White, approved Brown, and warm Gray")
ax.grid(alpha=.2)
ax.legend()
fig.savefig(root / "noise-options.png", dpi=180)
(root / "noise-options.json").write_text(json.dumps(results, indent=2)+"\n")
print("PASS: spectrum, headroom, transitions, and exact Brown preservation")
