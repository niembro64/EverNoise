"""Reproduce the historical build-23 filter and engine spectrum audit.

Current normalized-output comparisons use check-frequency-tapers.py instead.
Keep the design-1 record here so old render artifacts remain reproducible.
"""
from pathlib import Path
import hashlib, json, re, sys, warnings
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy import signal
from scipy.io import wavfile

root = Path(sys.argv[1])
design = json.loads(Path("Store/complementary-design-v1.json").read_text())
engine = json.loads((root/"engine-analysis.json").read_text())
impulse = np.fromfile(root/"impulses.f64",dtype=np.float64).reshape(4,192000)
nfft = 1048576
frequency = np.fft.rfftfreq(nfft,1/48000)
transfer = np.fft.rfft(impulse,n=nfft,axis=1)
mask = (frequency>=20)&(frequency<=20000)
power_error = np.sum(abs(transfer[:3,mask])**2,axis=0)/abs(transfer[3,mask])**2-1
maximum_error = float(np.max(abs(power_error)))
assert maximum_error<2e-10, maximum_error

centers = np.geomspace(20,20000,600)
def smooth(f,p):
    return np.array([np.mean(p[(f>=c*2**(-1/24))&(f<=c*2**(1/24))]) for c in centers])

curves, density, rms = {}, {}, {}
warnings.filterwarnings("ignore",category=wavfile.WavFileWarning)
for name in ["low","mid","high","equal","default","legacy-default"]:
    rate,x = wavfile.read(root/"engine"/("spectrum-"+name+".wav"))
    assert rate==48000 and x.shape==(3120000,2)
    x=x[rate:].astype(np.float64)
    f,psd=signal.welch(x,rate,nperseg=96000,noverlap=48000,axis=0,detrend=False)
    psd=psd.mean(axis=1)
    density[name]=psd;curves[name]=smooth(f,psd);rms[name]=float(np.sqrt(np.mean(x*x)))

common_power=np.interp(f,frequency,abs(transfer[3])**2)*2/(3*48000)
theory=smooth(f,common_power)
statistical_error=10*np.log10(curves["equal"]/theory)
error95=float(np.percentile(abs(statistical_error),95))
assert error95<.5,error95

reference=float(np.interp(1000,centers,theory))
db=lambda x:10*np.log10(np.maximum(x,1e-30)/reference)
fig,axes=plt.subplots(2,1,figsize=(10,8),constrained_layout=True)
colors={"low":"#ad6c66","mid":"#5f8e60","high":"#677fb4"}
for name in colors:
    axes[0].semilogx(centers,db(curves[name]),color=colors[name],lw=1.3,label=name.title())
axes[0].semilogx(centers,db(curves["equal"]),color="#242c38",lw=2.2,label="Measured combined output, equal settings")
axes[0].semilogx(centers,db(theory),color="#888888",ls="--",lw=1,label="Designed common spectrum")
axes[0].set(title="Complementary bands preserve one warm base spectrum",ylabel="Power density (dB relative to target at 1 kHz)",ylim=(-55,20))
for hz in [200,2000]:axes[0].axvline(hz,color="#aaaaaa",lw=.6,ls=":")
for name,color,label in [("legacy-default","#9b8d7e","Build 22 favorite: separate Brown/Mid/Air layers"),
                         ("default","#4a536f","Build 23: complementary pink-weighted bands")]:
    axes[1].semilogx(centers,10*np.log10(curves[name]/rms[name]**2),color=color,lw=2,label=label)
axes[1].set(title="Same buttons 3 / 3 / 2; normalized to equal RMS to compare tone",
            ylabel="Power density normalized to unit total power (dB/Hz)",ylim=(-70,-10))
for ax in axes:
    ax.set(xlim=(20,20000),xlabel="Frequency (Hz)")
    ax.set_xticks([20,50,100,200,500,1000,2000,5000,10000,20000],["20","50","100","200","500","1k","2k","5k","10k","20k"])
    ax.grid(alpha=.2);ax.legend(fontsize=8,loc="lower left")
fig.savefig("Store/complementary-spectrum-v23.png",dpi=170)

endurance=[]
for name in ["low","mid","high"]:
    log=(root/("endurance-"+name+".log")).read_text()
    m=re.search(r"PASS source=(\d+) hours=([\d.]+) frames=(\d+) switches=(\d+) CPU_seconds=([\d.]+)",log)
    assert m and float(m[2])==30 and int(m[3])==5184000000
    channels=[]
    for c in re.finditer(r"channel=(\d+) peak=([\d.]+) rms=([\d.]+) mean=([-\d.]+) minimum_block_rms=([\d.]+)",log):
        channels.append({"channel":int(c[1]),"peak":float(c[2]),"rms":float(c[3]),"mean":float(c[4]),"minimumBlockRMS":float(c[5])})
    assert len(channels)==2
    endurance.append({"band":name,"hours":30,"framesPerChannel":int(m[3]),"stereoChanges":int(m[4]),"CPUSeconds":float(m[5]),"channels":channels})

report={"design":design,"compiledImpulseComplementarityMaximumRelativeError_20HzTo20kHz":maximum_error,
        "measuredEqualMixVsExpectedPSD95thPercentileErrorDB":error95,
        "spectrumMethod":"65 s production stereo renders at 48 kHz; first second excluded; 2 s Hann Welch, 50% overlap; channel mean; 1/12-octave smoothing.",
        "rawRMS":rms,"defaultRMSChangeVsBuild22DB":float(20*np.log10(rms["default"]/rms["legacy-default"])),
        "timbralComparisonNormalization":"Both defaults normalized independently to equal total RMS; not equal perceived loudness or acoustic SPL.",
        "engineRenders":engine,"acceleratedEndurance":endurance,
        "compiledFilterAudit":(root/"filter-audit.log").read_text(),
        "physicalDeviceOvernightOrBatteryTest":False,
        "sourceSHA256":{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(Path("Sources/BrownNoiseDSP").rglob("*")) if p.is_file()},
        "analysisScriptSHA256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
Path("Store/complementary-audit-v23.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps({k:v for k,v in report.items() if k in ["compiledImpulseComplementarityMaximumRelativeError_20HzTo20kHz","measuredEqualMixVsExpectedPSD95thPercentileErrorDB","rawRMS","defaultRMSChangeVsBuild22DB"]},indent=2))
