"""Signal audit, independent FFT/resampling analysis. No app dependency.

uv run --with numpy --with scipy --with matplotlib python scripts/check-spectrum.py build/audio-audit-v2
"""
import json
import sys
import warnings
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy import signal
from scipy.io import wavfile

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("build/audio-audit-v2")
results, curves = {}, {}


def audit(label, samples, rate, revised):
    x = np.asarray(samples, dtype=np.float64)[int(rate):]  # Exclude initial fade.
    assert x.size > rate and np.isfinite(x).all()
    f, psd = signal.welch(x, rate, nperseg=int(rate * 2), detrend=False)
    df = f[1] - f[0]
    total_power = np.sum(psd) * df
    centers = np.array([125, 250, 500, 1000])
    levels = np.array([10 * np.log10(np.mean(psd[(f >= c / 1.1) & (f < c * 1.1)])) for c in centers])
    slope = np.polyfit(np.log2(centers[:3]), levels[:3], 1)[0]
    slope_1k = np.polyfit(np.log2(centers), levels, 1)[0]
    bands = [(0, 20), (20, 60), (60, 125), (125, 500), (500, 2000), (2000, rate / 2)]
    energy = {f"{lo:g}-{hi:g}_Hz": float(np.sum(psd[(f >= lo) & (f < hi)]) * df / total_power * 100) for lo, hi in bands}
    # Independent 8x band-limited interpolation estimate, including source
    # samples and Apple's converted output. This is not a hardware DAC test.
    true_peak = max(float(np.max(np.abs(x))), float(np.max(np.abs(signal.resample_poly(x, 8, 1)))))
    width = int(rate)
    windows = x[:len(x) // width * width].reshape(-1, width)
    rms_windows = np.sqrt(np.mean(windows ** 2, axis=1))
    steps = np.abs(np.diff(x))
    result = {
        "sample_rate": rate,
        "analyzed_seconds": len(x) / rate,
        "mean": float(np.mean(x)),
        "rms": float(np.sqrt(np.mean(x ** 2))),
        "sample_peak": float(np.max(np.abs(x))),
        "true_peak_8x_estimate": true_peak,
        "true_peak_dBFS": float(20 * np.log10(true_peak)),
        "full_scale_samples": int(np.count_nonzero(np.abs(x) >= 1)),
        "zero_samples": int(np.count_nonzero(x == 0)),
        "slope_125_500_dB_per_octave": float(slope),
        "slope_125_1000_dB_per_octave": float(slope_1k),
        "energy_percent": energy,
        "one_second_rms_min_median_max": [float(np.min(rms_windows)), float(np.median(rms_windows)), float(np.max(rms_windows))],
        "max_sample_step": float(np.max(steps)),
    }
    if revised:
        assert true_peak < 0.30, (label, "Unexpected peak", true_peak)
        assert abs(result["mean"]) < 0.001
        assert result["full_scale_samples"] == 0
        assert result["zero_samples"] == 0
        assert -7.0 < slope < -5.0, (label, slope)
        assert energy["0-20_Hz"] < 4.0, (label, energy)
        assert np.min(rms_windows) > 0.02
    results[label] = result
    curves[label] = (f, psd)
    print(f"{label}: peak={result['sample_peak']:.6f}, 8x peak={true_peak:.6f} ({result['true_peak_dBFS']:.2f} dBFS), RMS={result['rms']:.6f}, slope125–500={slope:.2f} dB/oct, sub20={energy['0-20_Hz']:.2f}%")


if (root / "v1.f32").exists():
    audit("build1_source", np.fromfile(root / "v1.f32", dtype=np.float32), 48000, False)
audit("build2_source", np.fromfile(root / "v2.f32", dtype=np.float32), 8000, True)
for path in sorted(root.glob("engine-*.wav")):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", wavfile.WavFileWarning)
        rate, samples = wavfile.read(path)
    if samples.ndim == 2:
        assert np.array_equal(samples[:, 0], samples[:, 1])
        samples = samples[:, 0]
    audit(path.stem, samples, rate, True)

# This transfer function is derived separately from the five recurrences,
# then compared to measured PSD after level normalization.
f, measured = curves["build2_source"]
z = np.exp(-2j * np.pi * f / 8000)
a, p, q = np.exp(-2 * np.pi * np.array([18, 35, 1400]) / 8000)
h = ((1-a) / (1-a*z)) * (p*(1-z)/(1-p*z))**2 * ((1-q)/(1-q*z))**2
power = np.abs(h)**2
band = (f >= 100) & (f <= 3000)
ratio_db = 10*np.log10(measured[band] / power[band])
shape_error = ratio_db - np.median(ratio_db)
assert np.percentile(np.abs(shape_error), 95) < 2.0
results["analytic_shape_error_95th_percentile_dB"] = float(np.percentile(np.abs(shape_error), 95))

# Reproduce the old nonlinear stage's pure-tone distortion independently.
n = np.arange(48000)
tone = np.sqrt(2)*0.22*np.sin(2*np.pi*1000*n/48000)
shaped = tone/(1+np.abs(tone))
spectrum = np.abs(np.fft.rfft(shaped))
thd = np.sqrt(np.sum(spectrum[np.arange(2, 24)*1000]**2))/spectrum[1000]
results["build1_waveshaper_1000Hz_input_rms_0.22_THD_percent"] = float(thd*100)

fig, axes = plt.subplots(2, 1, figsize=(9, 7), constrained_layout=True)
for label, color in [("build1_source", "#9b7662"), ("build2_source", "#207e79")]:
    if label not in curves:
        continue
    f, psd = curves[label]
    # Match only the graph's 125–500 Hz average to compare texture, not volume.
    reference = np.mean(psd[(f >= 125) & (f <= 500)])
    axes[0].semilogx(f[1:], 10*np.log10(psd[1:]/reference), label=label.replace("_source", "").replace("build", "Build "), color=color)
axes[0].set(xlim=(5, 20000), ylim=(-65, 30), xlabel="Frequency (Hz)", ylabel="Relative power density (dB)", title="Noise spectrum — matched 125–500 Hz level for comparison")
axes[0].grid(alpha=.25)
axes[0].legend()
x = np.fromfile(root / "v2.f32", dtype=np.float32)
t = np.arange(len(x))/8000
axes[1].plot(t, x, color="#207e79", linewidth=.3)
axes[1].axhline(.75, color="#777777", linestyle="--", linewidth=1)
axes[1].axhline(-.75, color="#777777", linestyle="--", linewidth=1)
axes[1].set(xlim=(0, 64), ylim=(-1, 1), xlabel="Time (seconds)", ylabel="Amplitude (full scale = ±1)", title="Build 2 source — fixed gain, no peak shaping; dashed lines show source bound")
fig.savefig(root / "signal-audit.png", dpi=180)
(root / "signal-audit.json").write_text(json.dumps(results, indent=2) + "\n")
print(f"PASS: wrote {root / 'signal-audit.json'} and signal-audit.png")
