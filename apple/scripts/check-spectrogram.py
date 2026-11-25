#!/usr/bin/env python3
"""Independent NumPy/SciPy audit of the Max-only spectrum display.

Checks actual PCM, Parseval calibration, octave-energy units, resolution blends,
linear-power temporal filtering, sample-clock partitions and analysis cost.
The FFT/row oracle uses double precision; the app uses Accelerate float FFTs.
"""
import argparse
import ctypes as C
import json
import re
import time
from pathlib import Path
import numpy as np
from scipy.signal import lfilter, sosfreqz
from scipy.sparse import csr_matrix

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--library', type=Path, default=root/'build/spectrum-smooth/libAudit.dylib')
parser.add_argument('--report', type=Path, default=root/'build/spectrum-smooth/analysis-audit.json')
args = parser.parse_args()
lib = C.CDLL(str(args.library.resolve()))
ptr = C.c_void_p
for name, params, result in [
    ('BNMixCreate', [C.c_uint64], ptr), ('BNMixDestroy', [ptr], None),
    ('BNMixRender', [ptr,ptr,ptr,C.c_uint32], None),
    ('BNSpectrumCreate', [], ptr), ('BNSpectrumDestroy', [ptr], None),
    ('BNSpectrumReset', [ptr], None),
    ('BNSpectrumConsume', [ptr,ptr,C.c_uint32,ptr,ptr,C.c_uint32], C.c_uint32),
    ('BNSpectrumCopyPower', [ptr,ptr], None), ('BNSpectrumCopyLowPower', [ptr,ptr], None),
    ('BNSpectrumReferenceWeights', [C.c_double,ptr], None)]:
    function = getattr(lib, name); function.argtypes = params; function.restype = result
N, rate, hop, rows, padding, taps, delay = 32768, 48000, 800, 1024, 4, 257, 128
warmup = N*8+taps-1
frequency = np.geomspace(2, 48000, rows); valid = frequency <= rate/2
sizes = np.array([32768,16384,8192,32768,16384,8192,4096])
rates = np.array([6000,6000,6000,48000,48000,48000,48000])
windows = [.5-.5*np.cos(2*np.pi*np.arange(n)/n) for n in sizes]
dtype = np.dtype([('left','f4'),('right','f4'),('frame','u8')])
header = (root/'Sources/SpectrumAnalysis/BNSpectrumDecimation.h').read_text()
fir = np.array([float(x) for x in re.findall(r'([-+]?\d\.\d+e[-+]\d+)f', header)], dtype='f4')
assert len(fir) == taps
first_decimated = ((taps+7)//8)*8-1

def consume(analyzer, pcm, offset=0, capacity=None):
    frames = np.empty(len(pcm), dtype=dtype)
    frames['left'], frames['right'] = pcm.T
    frames['frame'] = np.arange(offset, offset+len(pcm), dtype='u8')
    if capacity is None: capacity = len(pcm)//hop+2
    columns = np.zeros((capacity, rows), dtype='f4'); ends = np.zeros(capacity,dtype='u8')
    made = lib.BNSpectrumConsume(analyzer, frames.ctypes.data, len(frames), columns.ctypes.data, ends.ctypes.data, capacity)
    return columns[:made].copy(), ends[:made].copy()

def psd(x, stage):
    n, fs, w = sizes[stage], rates[stage], windows[stage]
    density = np.mean(abs(np.fft.rfft(x*w[:,None], n=int(n*padding), axis=0))**2, axis=1)*2/(fs*np.sum(w*w))
    density[[0,-1]] *= .5
    return density

# Build a separate sparse integration oracle directly from continuous
# log-frequency Gaussian integrals and their discrete quadrature measure.
distance = (np.log2((sizes/rates)[None,:]/(96/frequency[:,None]))/.65)**2
mix = np.exp(-.5*(distance-distance.min(axis=1,keepdims=True)))
mix[mix < 1e-8] = 0
kernels = []
for stage, (n, fs) in enumerate(zip(sizes, rates)):
    bins = np.arange(n*padding//2+1)*fs/(n*padding)
    row_indices, col_indices, data = [], [], []
    for row, hz in enumerate(frequency):
        if not valid[row] or mix[row,stage] == 0: continue
        sigma = np.hypot(1/12/2.354820045, .12/(hz*np.log(2)))
        chosen = np.flatnonzero((bins >= hz*2**(-6*sigma)) & (bins <= hz*2**(6*sigma)) & (bins > 0))
        if not len(chosen): mix[row,stage] = 0; continue
        weights = np.exp(-.5*(np.log2(bins[chosen]/hz)/sigma)**2)
        measure = 1/(bins[chosen]*np.log(2))
        measure[chosen == n*padding//2] *= .5
        weights /= np.dot(weights, measure)
        row_indices.extend([row]*len(chosen)); col_indices.extend(chosen); data.extend(weights)
    kernels.append(csr_matrix((data,(row_indices,col_indices)),shape=(rows,len(bins))))
mix /= mix.sum(axis=1, keepdims=True)

def reference_column(pcm):
    low = lfilter(fir.astype('f8'), [1], pcm.astype('f8'), axis=0)[first_decimated::8]
    densities = [psd(low[-n:] if stage < 3 else pcm[-delay-n:-delay], stage)
                 for stage,n in enumerate(sizes)]
    power = sum((kernel @ density)*mix[:,stage] for stage,(kernel,density) in enumerate(zip(kernels,densities)))
    return power, densities

# Real production PCM, not an idealized crossover drawing.
generator = lib.BNMixCreate(7823462); assert generator
left = np.zeros(96000,dtype='f4'); right = left.copy()
lib.BNMixRender(generator,left.ctypes.data,right.ctypes.data,len(left))
left = np.zeros(warmup+hop*12,dtype='f4'); right = left.copy()
lib.BNMixRender(generator,left.ctypes.data,right.ctypes.data,len(left)); lib.BNMixDestroy(generator)
pcm = np.column_stack((left,right))
analyzer = lib.BNSpectrumCreate(); assert analyzer
columns, ends = consume(analyzer,pcm)
assert len(columns) == 13
assert np.array_equal(ends, warmup-1-delay+np.arange(13)*hop)
assert np.all(np.isfinite(columns[:,valid])) and np.all(np.isnan(columns[:,~valid]))
reference, densities = reference_column(pcm[:warmup])
alpha = -np.expm1(-hop/rate/.08)
smoothed = np.tile(reference,(3,1))
expected = [reference]
for i in range(1,len(columns)):
    p,_ = reference_column(pcm[:warmup+i*hop])
    for layer in range(3):
        smoothed[layer] += alpha*(p-smoothed[layer]); p = smoothed[layer]
    expected.append(p.copy())
reference_db = 10*np.log10(np.maximum(expected,1e-20))
error = np.abs(columns[:,valid]-reference_db[:,valid])
visible_error = np.abs(np.maximum(columns[:,valid],-100)-np.maximum(reference_db[:,valid],-100))
assert np.max(visible_error) < .005, np.max(visible_error)

# Parseval check at the final sample endpoint using unsmoothed raw PSD/Hz.
_, densities = reference_column(pcm)
raw_errors=[]
for stage,copy in [(3,lib.BNSpectrumCopyPower),(0,lib.BNSpectrumCopyLowPower)]:
    actual = np.empty(N//2+1,dtype='f4'); copy(analyzer,actual.ctypes.data)
    expected_raw = densities[stage][::padding]
    relative = np.linalg.norm(actual-expected_raw)/np.linalg.norm(expected_raw)
    integrated = float(np.sum(actual,dtype='f8')*rates[stage]/N)
    expected_integrated = float(np.sum(expected_raw)*rates[stage]/N)
    assert relative < 1e-5 and abs(integrated-expected_integrated) < 1e-7
    raw_errors.append(dict(sampleRate=int(rates[stage]),relativePSDError=float(relative),integratedPower=integrated,referencePower=expected_integrated))

# Gain changes retain their exact dB meaning through every window and smoother.
lib.BNSpectrumReset(analyzer)
quieter,quiet_ends = consume(analyzer,pcm*.5)
assert np.array_equal(ends,quiet_ends)
gain_error=float(np.max(np.abs(quieter[:,valid]-columns[:,valid]+20*np.log10(2))))
assert gain_error < .001

# Different callback partitions must yield identical values and sample times.
lib.BNSpectrumReset(analyzer)
parts=[]; part_ends=[]; position=0; iteration=0
while position < len(pcm):
    count=min([4096,117,2047,37,3073][iteration%5],len(pcm)-position)
    c,e=consume(analyzer,pcm[position:position+count],position)
    parts.extend(c);part_ends.extend(e);position+=count;iteration+=1
assert np.array_equal(part_ends,ends)
assert np.array_equal(np.array(parts)[:,valid],columns[:,valid])

# Analytical quadrature: 1/f is constant per octave, white is +3.0103 dB/oct.
# This probes all blend boundaries independently of stochastic FFT variance.
pink = sum((kernel @ np.divide(1,np.arange(kernel.shape[1])*fs/(n*padding),out=np.zeros(kernel.shape[1]),where=np.arange(kernel.shape[1])>0))*mix[:,stage]
           for stage,(kernel,n,fs) in enumerate(zip(kernels,sizes,rates)))
white = sum((kernel @ np.ones(kernel.shape[1]))*mix[:,stage] for stage,kernel in enumerate(kernels))
interior=(frequency >= 10)&(frequency <= 18000)
pink_error=float(np.max(abs(10*np.log10(pink[interior]/np.log(2)))))
white_error=10*np.log10(white[interior]/(frequency[interior]*np.log(2)))
assert pink_error < 1e-5 and np.max(abs(white_error)) < .01

# Actual FFTs on deterministic pink noise: measure all resolutions over time.
# Average linear power, never dB. This is also a 60-second throughput benchmark.
seconds=60; rng=np.random.default_rng(716239)
length=warmup+seconds*rate
bins=np.fft.rfftfreq(length,1/rate)
spectral=np.exp(1j*rng.uniform(0,2*np.pi,(len(bins),2)))
spectral /= np.sqrt(np.maximum(bins[:,None],.2)); spectral[0]=0
pink_pcm=np.fft.irfft(spectral,n=length,axis=0)
pink_pcm *= .1/np.std(pink_pcm)
pink_pcm=pink_pcm.astype('f4')
lib.BNSpectrumReset(analyzer)
position=0; iteration=0; count_columns=0; total=np.zeros(rows); last_end=None
start=time.perf_counter()
while position < length:
    count=min([4096,117,2047,37,3073][iteration%5],length-position)
    c,e=consume(analyzer,pink_pcm[position:position+count],position)
    if len(e):
        if last_end is not None: assert e[0]==last_end+hop
        assert np.all(np.diff(e)==hop); last_end=int(e[-1])
        total[valid]+=np.sum(10**(c[:,valid].astype('f8')/10),axis=0)
        count_columns+=len(c)
    position+=count;iteration+=1
elapsed=time.perf_counter()-start
assert count_columns==1+seconds*rate//hop
mean_db=10*np.log10(total[valid]/count_columns)
band=(frequency[valid]>=20)&(frequency[valid]<=18000)
residual=mean_db[band]-np.median(mean_db[band])
assert np.quantile(abs(residual),.95)<.6 and np.max(abs(residual))<1.2, np.max(abs(residual))

# Reference hue remains solely a function of equal-gain crossover power.
design=json.loads((root/'Store/complementary-design-v2.json').read_text())
reference_weights=np.array([abs(sosfreqz(sos,worN=frequency[valid],fs=rate)[1])**2 for sos in design['crossoverSOS']]).T
reference_weights/=reference_weights.sum(axis=1,keepdims=True)
actual_weights=np.zeros(reference_weights.shape,dtype='f8',order='C')
for i,hz in enumerate(frequency[valid]): lib.BNSpectrumReferenceWeights(hz,actual_weights[i].ctypes.data)
weight_error=float(np.max(abs(reference_weights-actual_weights)));assert weight_error<1e-10
lib.BNSpectrumDestroy(analyzer)
report=dict(passed=True,rows=rows,hop=hop,columnsPerSecond=rate/hop,axisHz=[2,48000],measuredLimitHz=24000,
    units='dBFS/octave',windowSamples=sizes.tolist(),windowSampleRates=rates.tolist(),
    windowSeconds=(sizes/rates).tolist(),fftPadding=padding,minimumWindowOverlap=1-hop/min(sizes[3:]),
    frequencyKernelFWHMOctaves=1/12,temporalStages=3,temporalStageSeconds=.08,warmupSeconds=warmup/rate,
    rawPSD=raw_errors,maximumRowErrorDB=float(np.max(error)),maximumVisibleRowErrorDB=float(np.max(visible_error)),
    maximumGainErrorDB=gain_error,partitionInvariant=True,analyticalPinkFlatnessErrorDB=pink_error,
    analyticalWhiteOctaveEnergyErrorDB=float(np.max(abs(white_error))),
    measuredPinkFlatness95PercentDB=float(np.quantile(abs(residual),.95)),measuredPinkFlatnessMaximumDB=float(np.max(abs(residual))),
    maximumReferenceWeightError=weight_error,benchmarkAudioSeconds=seconds+warmup/rate,benchmarkColumns=count_columns,
    analysisWallSeconds=elapsed,analysisRealtimeFraction=elapsed/(seconds+warmup/rate),
    benchmarkLimit='Host Mac analysis only, including Python transfer. Excludes Swift images and physical-device GPU/battery use.')
args.report.parent.mkdir(parents=True,exist_ok=True)
args.report.write_text(json.dumps(report,indent=2)+'\n')
np.savez_compressed(args.report.with_suffix('.npz'),frequency=frequency,productionColumns=columns,pinkMeanDB=mean_db)
print(json.dumps(report,indent=2))
