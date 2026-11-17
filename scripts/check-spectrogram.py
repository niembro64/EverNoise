#!/usr/bin/env python3
"""Independent NumPy/SciPy check of production PCM -> multiresolution PSD.

Build build/spectrum-color/libAudit.dylib from BrownNoiseDSP.c, BNMixRenderer.c,
BNCapture.c and BNSpectrum.c, linking Accelerate, before running this script.
"""
import ctypes as C
import argparse
import json
import re
import time
from pathlib import Path
import numpy as np
from scipy.signal import lfilter, sosfreqz

root = Path(__file__).resolve().parents[1]
out = root / 'build/spectrum-color'
parser = argparse.ArgumentParser()
parser.add_argument('--library', default='libAudit.dylib')
parser.add_argument('--report', default='analysis-audit.json')
args = parser.parse_args()
lib = C.CDLL(str(out / args.library))
ptr = C.c_void_p
lib.BNMixCreate.argtypes = [C.c_uint64]; lib.BNMixCreate.restype = ptr
lib.BNMixRender.argtypes = [ptr, ptr, ptr, C.c_uint32]
lib.BNMixDestroy.argtypes = [ptr]
lib.BNSpectrumCreate.restype = ptr
lib.BNSpectrumConsume.argtypes = [ptr, ptr, C.c_uint32, ptr, ptr, C.c_uint32]
lib.BNSpectrumConsume.restype = C.c_uint32
lib.BNSpectrumCopyPower.argtypes = [ptr, ptr]
lib.BNSpectrumCopyLowPower.argtypes = [ptr, ptr]
lib.BNSpectrumReferenceWeights.argtypes = [C.c_double, ptr]
lib.BNSpectrumDestroy.argtypes = [ptr]
N, rate, decimation, taps, delay = 32768, 48000, 8, 257, 128
warmup = N*decimation+taps-1
dtype = np.dtype([('left', 'f4'), ('right', 'f4'), ('frame', 'u8')])
generator = lib.BNMixCreate(7823462)
assert generator
left = np.zeros(96000, dtype='f4'); right = left.copy()
lib.BNMixRender(generator, left.ctypes.data, right.ctypes.data, len(left))
left = np.zeros(warmup, dtype='f4'); right = left.copy()
lib.BNMixRender(generator, left.ctypes.data, right.ctypes.data, warmup)
lib.BNMixDestroy(generator)
frames = np.empty(warmup, dtype=dtype)
frames['left'] = left; frames['right'] = right; frames['frame'] = np.arange(warmup)
columns = np.zeros((1, 512), dtype='f4'); ends = np.zeros(1, dtype='u8')
analyzer = lib.BNSpectrumCreate()
assert analyzer
assert lib.BNSpectrumConsume(analyzer, frames.ctypes.data, warmup, columns.ctypes.data, ends.ctypes.data, 1) == 1
assert ends[0] == warmup-1-delay
power = np.zeros(N//2+1, dtype='f4'); low_power = power.copy()
lib.BNSpectrumCopyPower(analyzer, power.ctypes.data)
lib.BNSpectrumCopyLowPower(analyzer, low_power.ctypes.data)
window = .5 - .5*np.cos(2*np.pi*np.arange(N)/N)

def reference_psd(l, r, fs):
    reference = (abs(np.fft.rfft(l*window))**2 + abs(np.fft.rfft(r*window))**2) / (fs*np.sum(window**2))
    reference[[0, -1]] *= .5
    time_power = np.sum((l.astype('f8')**2+r.astype('f8')**2)*window**2)/(2*np.sum(window**2))
    return reference, float(time_power)

# Verify the full-rate window and the anti-aliasing/decimation independently.
full_reference, full_time_power = reference_psd(left[-delay-N:-delay], right[-delay-N:-delay], rate)
header = (root / 'Sources/SpectrumAnalysis/BNSpectrumDecimation.h').read_text()
fir = np.array([float(x) for x in re.findall(r'([-+]?\d\.\d+e[-+]\d+)f', header)], dtype='f4')
assert len(fir) == taps
first_decimated = ((taps+decimation-1)//decimation)*decimation-1
low_left = lfilter(fir.astype('f8'), [1], left)[first_decimated::decimation]
low_right = lfilter(fir.astype('f8'), [1], right)[first_decimated::decimation]
assert len(low_left) == N
low_reference, low_time_power = reference_psd(low_left, low_right, rate/decimation)
errors = []
for measured, reference, time_power, fs in [(power, full_reference, full_time_power, rate),
                                          (low_power, low_reference, low_time_power, rate/decimation)]:
    relative_error = float(np.linalg.norm(measured-reference)/np.linalg.norm(reference))
    integrated = float(np.sum(measured, dtype='f8')*fs/N)
    assert relative_error < 1e-5
    assert abs(integrated-time_power) < 1e-7
    errors.append(dict(relativePSDError=relative_error, integratedPSD=integrated,
                       windowWeightedTimePower=time_power))

# Fractional-bin integration/interpolation on the log-frequency display rows.
frequency = np.geomspace(2, 48000, 512)
half_row = (48000/2)**(.5/511)
valid = frequency <= rate/2
assert np.all(np.isfinite(columns[0, valid]))
assert np.all(np.isnan(columns[0, ~valid]))

def row_density(density, fs, lo, hi):
    lo, hi = lo*N/fs, min(hi*N/fs, N/2)
    if hi-lo < 1:
        return np.interp(np.sqrt(lo*hi), np.arange(len(density)), density)
    bins = np.arange(int(np.floor(lo+.5)), int(np.floor(hi+.5))+1)
    overlaps = np.maximum(0, np.minimum(hi, bins+.5)-np.maximum(lo, bins-.5))
    return float(np.sum(density[bins]*overlaps)/(hi-lo))

row_reference = []
for hz in frequency[valid]:
    lo, hi = hz/half_row, hz*half_row
    p = row_density(full_reference, rate, lo, hi)
    if hz < 80:
        q = row_density(low_reference, rate/decimation, lo, hi)
        t = np.clip(np.log2(hz/40), 0, 1); t = t*t*(3-2*t)
        p = q*(1-t)+p*t
    row_reference.append(10*np.log10(max(p, 1e-20)))
row_error = float(np.max(abs(columns[0, valid]-row_reference)))
assert row_error < .001

# Fixed hue follows equal-gain crossover power, not the current Low/Mid/High mix.
design = json.loads((root / 'Store/complementary-design-v1.json').read_text())
reference_weights = np.array([abs(sosfreqz(sos, worN=frequency[valid], fs=rate)[1])**2
                              for sos in design['crossoverSOS']]).T
reference_weights /= reference_weights.sum(axis=1, keepdims=True)
actual_weights = np.zeros(reference_weights.shape, dtype='f8', order='C')
for i, hz in enumerate(frequency[valid]):
    lib.BNSpectrumReferenceWeights(hz, actual_weights[i].ctypes.data)
weight_error = float(np.max(abs(reference_weights-actual_weights)))
assert weight_error < 1e-10

# Exercise arbitrary consumer partitions and all 23.4375 columns/s for a minute.
# Audio production, Swift image generation and device GPU work are excluded.
batch = frames[:4096].copy()
more_columns = np.zeros((3, 512), dtype='f4'); more_ends = np.zeros(3, dtype='u8')
total_frames = rate*60
position = warmup; column_count = 0; last_end = int(ends[0]); iteration = 0
start = time.perf_counter()
while position < warmup+total_frames:
    count = min([4096, 117, 2047, 37, 3073][iteration % 5], warmup+total_frames-position)
    batch['frame'] = np.arange(position, position+4096)
    made = lib.BNSpectrumConsume(analyzer, batch.ctypes.data, count, more_columns.ctypes.data, more_ends.ctypes.data, 3)
    for end in more_ends[:made]:
        assert end == last_end+2048
        last_end = int(end)
    column_count += made
    position += count; iteration += 1
elapsed = time.perf_counter()-start
assert column_count == total_frames//2048
lib.BNSpectrumDestroy(analyzer)
report = dict(passed=True, FFTSize=N, sampleRate=rate, hop=2048, rows=512,
              axisHz=[2,48000], measuredLimitHz=24000, decimation=decimation,
              lowFrequencyBinHz=rate/decimation/N, lowWindowSeconds=N*decimation/rate,
              warmupSeconds=warmup/rate, fullRate=errors[0], lowRate=errors[1],
              maximumRowErrorDB=row_error, maximumReferenceWeightError=weight_error,
              secondsOfAudio=60, columnsProcessed=column_count, analysisWallSeconds=elapsed,
              benchmarkLimit='Host-Mac analysis only; excludes image generation and physical-device GPU/battery use.')
(out / args.report).write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
