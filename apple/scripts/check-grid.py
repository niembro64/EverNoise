"""Measure the production three-layer graph across the whole sound grid."""
import json
import sys
import warnings
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root=Path(sys.argv[1]) if len(sys.argv)>1 else Path('build/noise-grid-v5')
results={}; curves={}
warnings.simplefilter('ignore', wavfile.WavFileWarning)
for path in sorted(root.glob('grid-*.wav')):
    rate,data=wavfile.read(path)
    if data.ndim==2:
        assert np.array_equal(data[:,0],data[:,1]),path
        data=data[:,0]
    x=data[rate:].astype(np.float64)
    assert np.isfinite(x).all()
    peak=float(np.max(np.abs(signal.resample_poly(x,8,1))))
    f,p=signal.welch(x,rate,nperseg=rate,detrend=False)
    stats=json.loads(Path(str(path)+'.json').read_text())
    stats.update(true_peak_8x=peak,true_peak_dBFS=float(20*np.log10(peak)),dc_mean=float(x.mean()))
    assert peak<.32 and abs(x.mean())<.001,(path,peak)
    assert stats['silent_blocks']==0 and stats['min_block_rms']>.002,path
    # A 128-frame callback spans only 2.7 ms and can sit in a natural trough.
    # Measure level stability over 100 ms independently of callback size.
    width=int(rate*.1)
    windows=x[:len(x)//width*width].reshape(-1,width)
    stats['min_100ms_rms']=float(np.sqrt(np.mean(windows*windows,axis=1)).min())
    assert stats['min_100ms_rms']>.015,path
    for band,(lo,hi) in {'bass':(20,200),'mid':(1000,3000),'high':(8000,12000)}.items():
        power=float(p[(f>=lo)&(f<hi)].sum())
        stats[band+'_power_dB']=float(10*np.log10(max(power,1e-20)))
    if path.stem in ['grid-48000-0-0','grid-44100-0-0','grid-48000-4-0']:
        old=Path(f'build/audio-audit-v2/engine-{rate}.wav') if stats['highs']==0 else Path('build/noise-options/gray-48000.wav')
        _,reference=wavfile.read(old)
        stats['matches_previous_sound_exactly']=bool(np.array_equal(data,reference[:len(data),0]))
        assert stats['matches_previous_sound_exactly'],path
    if rate==48000 and path.stem in ['grid-48000-0-0','grid-48000-4-0','grid-48000-0-4','grid-48000-4-4','grid-48000-2-2']:
        curves[path.stem]=(f,p)
    results[path.stem]=stats
    print(f"{path.stem}: RMS={stats['rms']:.6f}, estimated peak={peak:.6f}, silent blocks={stats['silent_blocks']}")

cells=np.array([[results[f'grid-48000-{h}-{m}']['bass_power_dB'] for h in range(5)] for m in range(5)])
bass_range=float(np.ptp(cells))
assert bass_range<.05,bass_range
for mids in range(5):
    high=np.array([results[f'grid-48000-{h}-{mids}']['high_power_dB'] for h in range(5)])
    assert (np.diff(high)>0).all(),high
for highs in range(5):
    mid=np.array([results[f'grid-48000-{highs}-{m}']['mid_power_dB'] for m in range(5)])
    assert (np.diff(mid)>0).all(),mid

fig,ax=plt.subplots(figsize=(9,5),constrained_layout=True)
for name,(f,p) in curves.items():
    h,m=map(int,name.split('-')[-2:])
    ax.semilogx(f[1:],10*np.log10(np.maximum(p[1:],1e-20)),label=f'Highs {h}, mids {m}',color=(.70,.07+.16*m,.07+.16*h),linewidth=1.2)
ax.set(xlim=(20,20000),ylim=(-110,-40),xlabel='Frequency (Hz)',ylabel='Power density (dBFS/Hz)',title='Sound grid: constant bass with adjustable mids and highs')
ax.grid(alpha=.2);ax.legend();fig.savefig(root/'grid-spectrum.png',dpi=180)
(root/'grid-measurements.json').write_text(json.dumps({'bass_band_variation_dB':bass_range,'renders':results},indent=2)+'\n')
print(f'PASS: all 25 cells; bass variation {bass_range:.6f} dB; monotonic axes; exact old Brown/Gray; transitions and headroom.')
