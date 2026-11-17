#!/usr/bin/env python3
"""Independent NumPy check of production PCM -> calibrated Accelerate PSD."""
import ctypes as C
import json
import time
from pathlib import Path
import numpy as np

lib = C.CDLL(str(Path('build/spectrogram/libAudit.dylib').resolve()))
ptr = C.c_void_p
lib.BNMixCreate.argtypes = [C.c_uint64]; lib.BNMixCreate.restype = ptr
lib.BNMixRender.argtypes = [ptr, ptr, ptr, C.c_uint32]
lib.BNMixDestroy.argtypes = [ptr]
lib.BNSpectrumCreate.restype = ptr
lib.BNSpectrumConsume.argtypes = [ptr, ptr, C.c_uint32, ptr, ptr, C.c_uint32]
lib.BNSpectrumConsume.restype = C.c_uint32
lib.BNSpectrumCopyPower.argtypes = [ptr, ptr]
lib.BNSpectrumDestroy.argtypes = [ptr]
N = 32768
dtype = np.dtype([('left', 'f4'), ('right', 'f4'), ('frame', 'u8')])
generator = lib.BNMixCreate(7823462)
left = np.zeros(96000, dtype='f4'); right = left.copy()
lib.BNMixRender(generator, left.ctypes.data, right.ctypes.data, len(left))
left = np.zeros(N, dtype='f4'); right = left.copy()
lib.BNMixRender(generator, left.ctypes.data, right.ctypes.data, N)
lib.BNMixDestroy(generator)
frames = np.empty(N, dtype=dtype)
frames['left'] = left; frames['right'] = right; frames['frame'] = np.arange(N)
columns = np.zeros((1, 512), dtype='f4'); ends = np.zeros(1, dtype='u8')
analyzer = lib.BNSpectrumCreate()
assert lib.BNSpectrumConsume(analyzer, frames.ctypes.data, N, columns.ctypes.data, ends.ctypes.data, 1) == 1
power = np.zeros(N//2+1, dtype='f4')
lib.BNSpectrumCopyPower(analyzer, power.ctypes.data)
window = .5 - .5*np.cos(2*np.pi*np.arange(N)/N)
reference = (abs(np.fft.rfft(left*window))**2 + abs(np.fft.rfft(right*window))**2) / (48000*np.sum(window**2))
reference[[0, -1]] *= .5
relative_error = np.linalg.norm(power-reference)/np.linalg.norm(reference)
integrated = float(np.sum(power, dtype='f8')*48000/N)
weighted_time_power = float(np.sum((left.astype('f8')**2+right.astype('f8')**2)*window**2)/(2*np.sum(window**2)))
assert relative_error < 1e-5
assert abs(integrated-weighted_time_power) < 1e-7
assert np.all(np.isfinite(columns))

# Sustain all 23.4375 columns/s; includes the full 32768-point FFT for each ear.
batch = np.tile(frames[:4096], 1)
columns = np.zeros((2, 512), dtype='f4'); ends = np.zeros(2, dtype='u8')
total_frames = 48000*60
position = N; column_count = 0
start = time.perf_counter()
while position < N+total_frames:
    count = min(4096, N+total_frames-position)
    batch['frame'] = np.arange(position, position+4096)
    column_count += lib.BNSpectrumConsume(analyzer, batch.ctypes.data, count, columns.ctypes.data, ends.ctypes.data, 2)
    position += count
elapsed = time.perf_counter()-start
lib.BNSpectrumDestroy(analyzer)
report = dict(passed=True, FFTSize=N, sampleRate=48000, hop=2048, rows=512,
              relativePSDError=float(relative_error), integratedPSD=integrated,
              windowWeightedTimePower=weighted_time_power, secondsOfAudio=60,
              columnsProcessed=column_count, analysisWallSeconds=elapsed,
              benchmarkLimit='Host-Mac analysis only; excludes image generation and physical-device GPU/battery use.')
Path('build/spectrogram/analysis-audit.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report))
