"""Validate all 125 mixes against independent layer references and transitions."""
import json
import sys
import warnings
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('build/band-pickers-v7')
warnings.simplefilter('ignore', wavfile.WavFileWarning)
def read(path):
    rate, data = wavfile.read(path)
    if data.ndim == 2:
        assert np.array_equal(data[:, 0], data[:, 1]), path
        data = data[:, 0]
    assert np.isfinite(data).all(), path
    return rate, data

reference = [read(root / f'bands-48000-{l}-{m}-{h}.wav')[1].astype(np.float64)
             for l, m, h in [(4, 0, 0), (0, 4, 0), (0, 0, 4)]]
gains = np.array([0] + [10 ** (6 * (level - 4) / 20) for level in range(1, 5)])
results = {}
max_error = 0.0
preserved = 0
for path in sorted(root.glob('bands-*.wav')):
    rate, data = read(path)
    stats = json.loads(Path(str(path) + '.json').read_text())
    stable = data[rate:].astype(np.float64)
    peak = float(np.max(np.abs(signal.resample_poly(stable, 8, 1))))
    stats['true_peak_8x'] = peak
    stats['true_peak_dBFS'] = float(20 * np.log10(peak)) if peak else None
    assert peak < .32 and stats['render_retries'] == 0, path
    coordinates = stats['preset'].split(',')
    if len(coordinates) == 3:
        l, m, h = map(int, coordinates)
        if (l, m, h) == (0, 0, 0):
            assert np.count_nonzero(data) == 0, path
        else:
            assert stats['silent_blocks'] == 0, path
            width = int(rate * .1)
            windows = stable[:len(stable) // width * width].reshape(-1, width)
            stats['min_100ms_rms'] = float(np.sqrt(np.mean(windows * windows, axis=1)).min())
            assert stats['min_100ms_rms'] > 1e-6, path
        if rate == 48000 and stats['channels'] == 2:
            expected = sum(gain * ref for gain, ref in zip(gains[[l, m, h]], reference))
            error = float(np.max(np.abs(data.astype(np.float64) - expected)))
            max_error = max(max_error, error)
            stats['max_error_against_layer_sum'] = error
            assert error < 3e-7, (path, error)
            if l == 4:
                _, old = read(Path('build/log-scale-v6') / f'grid-48000-{h}-{m}.wav')
                assert np.array_equal(data, old[:len(data)]), path
                stats['matches_build6_exactly'] = True
                preserved += 1
    elif stats['preset'] == 'rapid':
        assert stats['silent_blocks'] == 0 and stats['transitions'] > 1500, path
    elif stats['preset'] == 'mute':
        # First two muted plateaus, allowing the 600 ms fade and SRC tail.
        assert np.count_nonzero(data[int(rate * 2.3):int(rate * 2.9)]) == 0, path
        assert np.count_nonzero(data[int(rate * 5.4):int(rate * 5.9)]) == 0, path
        assert float(np.sqrt(np.mean(data[int(rate * 4):int(rate * 4.5)] ** 2))) > .02, path
        stats['mute_and_restore_verified'] = True
    results[path.stem] = stats
assert len(results) == 135 and preserved == 25
report = {'renders': results, 'all_125_mixes_passed': True,
          'previous_balances_preserved_exactly': preserved,
          'max_sample_error_against_independent_layers': max_error,
          'max_true_peak_dBFS': max(s['true_peak_dBFS'] for s in results.values() if s['true_peak_dBFS'] is not None)}
(root / 'band-measurements.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'renders'}, indent=2))
print('PASS: 125 mixes, 25 exact previous balances, 135 renders, muted plateaus, transitions and headroom')
