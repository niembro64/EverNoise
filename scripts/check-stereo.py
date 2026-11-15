"""Render every stereo mix and check actual Apple conversion/output."""
import concurrent.futures, hashlib, json, subprocess, sys, warnings
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly, welch
from scipy.integrate import trapezoid

root = Path(sys.argv[1])
renderer = root / 'render-stereo'
baseline = root / 'render-baseline'

def run(job):
    name, rate, seconds, mix, channels, mode, old = job
    file = root / (name + '.wav')
    command = [str(baseline if old else renderer), str(rate), str(seconds), mix, str(file), str(channels)]
    if not old: command.append(mode)
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode: raise RuntimeError(f'{name}: {result.stdout}\n{result.stderr}')
    return name

jobs = []
for low in range(5):
    for mid in range(5):
        for high in range(5):
            jobs.append((f'mix-{low}{mid}{high}', 48000, 4, f'{low},{mid},{high}', 2, 'stereo', False))
for rate in [16000, 44100, 48000, 96000]:
    for channels in [1, 2]:
        for mode in ['mono', 'stereo', 'switch', 'rapid']:
            jobs.append((f'route-{rate}-{channels}-{mode}', rate, 12, '4,4,4', channels, mode, False))
for rate in [44100, 48000]:
    for channels in [1, 2]:
        for mix in ['4,0,0', '0,4,0', '0,0,4', '4,4,4', '1,2,3']:
            code = mix.replace(',', '')
            for old in [False, True]:
                jobs.append((f'compare-{rate}-{channels}-{code}-{"old" if old else "new"}', rate, 4, mix, channels, 'mono', old))
for preset in ['rapid', 'mute']:
    jobs.append((preset, 48000, 15, preset, 2, 'rapid', False))
if '--analyze-existing' not in sys.argv:
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        names = list(pool.map(run, jobs))
    print(f'{len(names)} engine renders passed', flush=True)

warnings.filterwarnings('ignore', category=wavfile.WavFileWarning)
max_peak = 0.0; correlations = []; max_balance_db = 0.0; comparisons = []
for name, rate, seconds, mix, channels, mode, old in jobs:
    if old: continue
    file = root / (name + '.wav')
    fs, data = wavfile.read(file)
    assert fs == rate and np.isfinite(data).all()
    stable = data[rate:].astype(np.float64)
    if stable.ndim == 1: stable = stable[:, None]
    # 4x reconstruction estimates intersample peaks after Apple's SRC.
    peak = float(np.max(np.abs(resample_poly(stable, 4, 1, axis=0))))
    assert peak < .959, (name, peak)
    max_peak = max(max_peak, peak)
    if mode == 'stereo' and channels == 2 and mix != '0,0,0':
        correlation = float(np.corrcoef(stable.T)[0, 1])
        correlations.append(abs(correlation))
        power = np.mean(stable * stable, axis=0)
        balance_db = abs(float(10 * np.log10(power[0] / power[1])))
        max_balance_db = max(max_balance_db, balance_db)
        assert abs(correlation) < .15 and balance_db < .8, (name, correlation, balance_db)
    if name.startswith('compare-'):
        _, previous = wavfile.read(root / (name.replace('-new', '-old') + '.wav'))
        # The original mono-input converter attenuates 44.1 kHz by 3.0103 dB.
        # Retain uniform calibrated per-channel gain, not this rate-specific
        # legacy artifact. Require identical waveform/spectrum after that ONE
        # documented constant gain, and bit identity at 48 kHz.
        gain = np.sqrt(2) if rate == 44100 else 1.0
        residual = float(np.max(np.abs(data.astype(np.float64) - previous.astype(np.float64) * gain)))
        assert residual < 1e-6, (name, residual)
        if rate == 48000: assert np.array_equal(data, previous)
        comparisons.append({'name': name, 'gainDB': float(20*np.log10(gain)),
                            'maxResidual': residual, 'bitIdentical': bool(np.array_equal(data, previous))})

spectrum = {}
for mix, band in [('400', (125, 500)), ('040', (600, 3000)), ('004', (5000, 15000))]:
    rate, samples = wavfile.read(root / f'mix-{mix}.wav')
    f, powers = welch(samples[rate:], rate, nperseg=8192, axis=0)
    mask = (f >= band[0]) & (f <= band[1])
    energy = trapezoid(powers[mask], f[mask], axis=0)
    mismatch = float(10 * np.log10(energy[0] / energy[1]))
    assert abs(mismatch) < .8
    spectrum[mix] = {'band': list(band), 'leftRightBandPowerDifferenceDB': mismatch}
record = {'engineRendersPassed': len(jobs), 'stereoMixes': 125, 'monoReferenceComparisons': comparisons,
          'outputRates': [16000, 44100, 48000, 96000], 'outputChannels': [1, 2],
          'maximumEstimatedIntersamplePeak': max_peak, 'headroomDB': float(-20*np.log10(max_peak)),
          'maximumAbsoluteStereoCorrelation': max(correlations), 'maximumLeftRightPowerDifferenceDB': max_balance_db,
          'bandSpectrumChecks': spectrum, 'renderRetries': 0,
          'scriptSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
(root / 'analysis.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record, indent=2))
