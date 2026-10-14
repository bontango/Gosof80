"""compare.py - compare two Votrax outputs.

  compare.py ref.f32 test.f32          SNR of test against ref (float32 files)
  compare.py --exact a.txt b.txt       bit exact check of two integer sample files
                                       (fixed point model vs. VHDL testbench)

SNR is given full band and below ~8 kHz (one pole low pass on both signals). The
band limited figure is what matters: PinMAME's "3rd order" filters carry an extra pole
at z = -1 (Nyquist, 20 kHz), which the biquads here do not have; any energy that
lands there is inaudible but would dominate a full band comparison.
"""
import math, struct, sys


def read_f32(p):
    d = open(p, "rb").read()
    return list(struct.unpack("<%df" % (len(d) // 4), d))


def lowpass(x, fc=8000.0, fs=40000.0):
    a = math.exp(-2 * math.pi * fc / fs)
    y, s = [], 0.0
    for v in x:
        s = (1 - a) * v + a * s
        y.append(s)
    return y


def snr(r, t):
    n = min(len(r), len(t))
    ps = sum(v * v for v in r[:n])
    pe = sum((a - b) ** 2 for a, b in zip(r[:n], t[:n]))
    me = max(abs(a - b) for a, b in zip(r[:n], t[:n]))
    return (10 * math.log10(ps / pe) if pe > 0 else float("inf")), me, n


if __name__ == "__main__":
    if sys.argv[1] == "--exact":
        a = [int(l) for l in open(sys.argv[2])]
        b = [int(l) for l in open(sys.argv[3])]
        n = min(len(a), len(b))
        bad = [i for i in range(n) if a[i] != b[i]]
        print("%d / %d samples compared, %d differ%s" % (
            n, max(len(a), len(b)), len(bad),
            "" if not bad else ", first at sample %d: %d vs %d" % (bad[0], a[bad[0]], b[bad[0]])))
        sys.exit(1 if bad or len(a) != len(b) else 0)
    r, t = read_f32(sys.argv[1]), read_f32(sys.argv[2])
    s_full, me, n = snr(r, t)
    s_lp, _, _ = snr(lowpass(r), lowpass(t))
    print("%-28s n=%d  SNR full %.1f dB  SNR <8k %.1f dB  max|err| %.4f" % (
        sys.argv[2].split("/")[-1], n, s_full, s_lp, me))
