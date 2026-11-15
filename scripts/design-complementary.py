"""Generate and verify the fixed 48 kHz complementary noise bank (design 1).

Requires NumPy/SciPy for offline design only; the app has no new dependency.
Use --write to regenerate the C header and checked-in numerical design record.
"""
from pathlib import Path
import argparse
import json
import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000.0
# Positive analog pole/zero frequencies from an offline least-squares fit to
# -10 log10(f) amplitude in dB over 20 Hz–20 kHz. Pairing in ascending order
# keeps every shelf attenuating at high frequency and limits internal state.
POLES = [15.158974249230978, 76.06050043086661, 288.1778570935381,
         1071.8245918168461, 3994.9818529284403, 15551.903647251507]
ZEROS = [37.22726567063349, 148.90730542954637, 555.9439764202084,
         2067.466942309204, 7745.83434500294, 21924.67060366246]


def design():
    shelves = []
    for pole, zero in zip(POLES, ZEROS):
        k, p, z = 2 * RATE, 2 * np.pi * pole, 2 * np.pi * zero
        shelves.append([(k+z)/(k+p)*p/z, (-k+z)/(k+p)*p/z, 0,
                        1, (-k+p)/(k+p), 0])
    shelves = np.array(shelves)
    hp = signal.butter(2, 20, btype="high", fs=RATE, output="sos")
    lp = signal.butter(2, 18000, fs=RATE, output="sos")
    low = signal.butter(2, 200, fs=RATE, output="sos")
    rest = signal.butter(2, 200, btype="high", fs=RATE, output="sos")
    mid = signal.butter(2, 2000, fs=RATE, output="sos")
    high = signal.butter(2, 2000, btype="high", fs=RATE, output="sos")
    common = np.vstack([hp, shelves, lp])
    crossovers = [low, np.vstack([rest, mid]), np.vstack([rest, high])]
    return shelves, hp, lp, [low, rest, mid, high], common, crossovers


def tail_bound(sos, start):
    """Bound the infinite impulse tail from distinct-pole residues.

    h[n] = sum(r_k p_k**n) for n > 0. Factored roots avoid forming a poorly
    conditioned high-order denominator. All sections have equal numerator and
    denominator order; a possible direct term only affects sample zero.
    """
    poles, zeros, gain = [], [], 1.0
    for row in sos:
        order = 1 if row[2] == 0 and row[5] == 0 else 2
        b, a = row[:order+1], row[3:4+order]
        zeros.extend(np.roots(b)); poles.extend(np.roots(a)); gain *= b[0]
    poles, zeros = np.array(poles), np.array(zeros)
    assert np.max(np.abs(poles)) < 1
    bound = 0.0
    for i, pole in enumerate(poles):
        others = np.delete(poles, i)
        assert np.min(np.abs(pole-others)) > 1e-7
        residue = gain * np.prod(1-zeros/pole) / np.prod(1-others/pole)
        bound += abs(residue) * abs(pole)**start / (1-abs(pole))
    return float(bound)


def audit():
    shelves, hp, lp, splits, common, crossovers = design()
    frequencies = np.unique(np.r_[np.linspace(0, RATE/2, 240001),
                                 np.geomspace(.01, RATE/2, 50000), 200, 2000])
    responses = [signal.sosfreqz(sos, worN=frequencies, fs=RATE)[1] for sos in crossovers]
    complement_error = float(np.max(np.abs(sum(abs(h)**2 for h in responses)-1)))
    assert complement_error < 2e-11
    pink_f = np.geomspace(20, 20000, 4000)
    pink_h = signal.sosfreqz(shelves, worN=pink_f, fs=RATE)[1]
    error = 20*np.log10(abs(pink_h)) + 10*np.log10(pink_f/1000)
    error -= np.mean(error)
    assert np.max(np.abs(error)) < .05
    impulse = np.zeros(int(RATE*4)); impulse[0] = 1
    filters = [np.vstack([common, split]) for split in crossovers]
    tails = [tail_bound(sos, len(impulse)) for sos in filters]
    impulses = [signal.sosfilt(sos, impulse) for sos in filters]
    l1 = np.array([np.sum(abs(h)) for h in impulses]) + tails
    # One shared gain preserves complementarity. The L1 sum bounds every mix
    # of independently bounded excitations and every gain in [0,1].
    gain = .8 * (1-1e-6) / sum(l1)
    energy = np.array([np.sum(h*h) for h in impulses])
    record = {"design": 1, "sampleRate": RATE, "crossoversHz": [200, 2000],
              "commonHighPassHz": 20, "commonLowPassHz": 18000,
              "pinkingAnalogPolesHz": POLES, "pinkingAnalogZerosHz": ZEROS,
              "maximumPinkingApproximationErrorDB_20HzTo20kHz": float(max(abs(error))),
              "frequencyPointsChecked": len(frequencies), "maximumComplementaryPowerError": complement_error,
              "unscaledImpulseL1Bounds": l1.tolist(), "infiniteTailBoundsAfter4Seconds": tails,
              "commonGain": float(gain), "bandAbsoluteBounds": (l1*gain).tolist(),
              "allBandsWorstCaseAbsoluteBound": float(sum(l1)*gain),
              "expectedFullMixRMS": float(gain*np.sqrt(sum(energy)/3)),
              "expectedDefaultMixRMS": float(gain*np.sqrt(np.dot(energy, np.array([10**(-12/20),10**(-12/20),10**(-18/20)])**2)/3)),
              "commonSOS": common.tolist(), "crossoverSOS": [x.tolist() for x in crossovers]}
    def row(values): return "{" + ", ".join(format(float(x), ".17g") for x in values) + "}"
    def second(name, values):
        v = values[0]
        return f"static const BNSecondOrderCoefficients {name} = {row([*v[:3], *v[4:]])};\n"
    header = """// Generated by scripts/design-complementary.py --write. Do not hand-edit.
#ifndef BN_COMPLEMENTARY_COEFFICIENTS_H
#define BN_COMPLEMENTARY_COEFFICIENTS_H
typedef struct { double b0, b1, a1; } BNFirstOrderCoefficients;
typedef struct { double b0, b1, b2, a1, a2; } BNSecondOrderCoefficients;
static const BNFirstOrderCoefficients BNPinkShelves[6] = {
"""
    header += ",\n".join("    "+row([v[0],v[1],v[4]]) for v in shelves) + "\n};\n"
    for name, value in [("BNSubsonic",hp),("BNUltrasonic",lp),*zip(["BNLowPass200","BNHighPass200","BNLowPass2000","BNHighPass2000"],splits)]:
        header += second(name, value)
    header += f"static const double BNComplementaryGain = {gain:.17g};\n"
    header += f"static const double BNComplementaryAbsoluteBounds[3] = {row(l1*gain)};\n#endif\n"
    return header, record


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--write", action="store_true")
    args = parser.parse_args(); header, record = audit()
    path = ROOT / "Sources/BrownNoiseDSP/BNComplementaryCoefficients.h"
    if args.write:
        path.write_text(header)
        (ROOT / "Store/complementary-design-v1.json").write_text(json.dumps(record,indent=2)+"\n")
    else:
        assert path.read_text() == header, "Generated coefficients differ; inspect before regenerating"
    print(json.dumps({k:v for k,v in record.items() if k not in ["commonSOS","crossoverSOS"]},indent=2))
