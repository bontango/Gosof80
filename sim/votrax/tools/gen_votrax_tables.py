"""gen_votrax_tables.py - tables for the FPGA Votrax SC-01 (fixed point C model + VHDL).

Source of truth is PinMAME's src/sound/votrax.c (Galibert core), local copy in
sim/votrax/pinmame/. This script
  1. reads the phoneme ROM sc01_bin[] from that file and unpacks it per phone code
     exactly like phone_commit() does,
  2. recomputes every filter of filters_commit() in double precision with the same
     formulas (build_standard_filter, build_injection_filter, build_noise_shaper_filter,
     build_lowpass_filter), for every possible parameter value,
  3. reduces the "3rd order" standard filters to the biquads they really are: both
     numerator and denominator carry the factor (1 + z^-1) (bilinear transform of a
     2nd order H(s), multiplied out), the remainder of the division is ~1e-16,
  4. quantises to the fixed point formats below and writes
       model/votrax_tables.h            (C, double + integer values)
       rtl/common/votrax/votrax_tables_pkg.vhd  (VHDL constants, with --vhdl)

KEY FACT: the coefficients do not depend on the main clock. k0, k1 ~ 1/cclock,
k2 ~ 1/cclock^2, w0 ~ cclock and zc ~ sclock cancel out (sclock = 2 cclock), so the
tables are computed once at the nominal 720 kHz and stay valid at any clock, as
long as the filters run at main/18. Checked below (assert).

ONE EXCEPTION, harmless: build_noise_shaper_filter. Its formulas are dimensionally
inconsistent (k0 has no clock term, k1 ~ cclock instead of 1/cclock) and WOULD depend
on the clock - but votrax.c builds it only in filters_commit(force=1), i.e. once at
start with the initial 720 kHz; votraxsc01_set_clock() calls filters_commit(0), which
leaves F4, FX and the noise shaper alone. So in PinMAME it is a constant, here too.

The noise source amplitude (1e4 in analog_calc) is folded into the noise shaper's
numerator (FN.a0/a2 * 1e4) so the coefficient is not tiny.

Run: python gen_votrax_tables.py [--vhdl]
"""
import math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SIM = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(SIM))
VOTRAX_C = os.path.join(SIM, "pinmame", "votrax.c")

# ---- fixed point formats (see docs/Votrax_SC01_Implementierung.md) -----------
COEF_BITS = 27          # signed coefficient word
COEF_FRAC = 24          # fractional bits: range [-4, 4)


# ---- phoneme ROM ------------------------------------------------------------
def read_rom(name="sc01_bin"):
    src = open(VOTRAX_C, encoding="latin-1").read()
    m = re.search(r"static const UINT8 %s\[512\]\s*=\s*\{(.*?)\};" % name, src, re.S)
    data = [int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]{2})", m.group(1))]
    assert len(data) == 512
    return [int.from_bytes(bytes(data[i * 8:i * 8 + 8]), "little") for i in range(64)]


def bit(v, n):
    return (v >> n) & 1


def bitswap(v, *bits):
    r = 0
    for b in bits:
        r = (r << 1) | bit(v, b)
    return r


def unpack_phone(rom, phone):
    for val in rom:
        if ((val >> 56) & 0x3F) == phone:
            return dict(
                f1=bitswap(val, 0, 7, 14, 21), va=bitswap(val, 1, 8, 15, 22),
                f2=bitswap(val, 2, 9, 16, 23), fc=bitswap(val, 3, 10, 17, 24),
                f2q=bitswap(val, 4, 11, 18, 25), f3=bitswap(val, 5, 12, 19, 26),
                fa=bitswap(val, 6, 13, 20, 27),
                cld=bitswap(val, 34, 32, 30, 28), vd=bitswap(val, 35, 33, 31, 29),
                closure=bit(val, 36),
                duration=bitswap(~val & ((1 << 64) - 1), 37, 38, 39, 40, 41, 42, 43),
                pause=1 if phone in (0x03, 0x3E) else 0)
    raise ValueError("phone %d not in ROM" % phone)


# ---- filters, as in votrax.c --------------------------------------------------
def standard(c1t, c1b, c2t, c2b, c3, c4, main=720000.0):
    cc, sc = main / 36.0, main / 18.0
    k0 = c1t / (cc * c1b)
    k1 = (c4 * c2t) / (cc * (c1b * c3))
    k2 = (c4 * c2b) / (cc * cc * (c1b * c3))
    w0 = math.sqrt(abs(cc * cc * (c3 * (c1t * c2t - c1b * c2b)) / (c2b * c4 * c2b)))
    wd = math.pi * sc
    if w0 > wd:
        w0 -= 2.0 * wd
    zc = w0 / math.tan(w0 / (2.0 * sc))
    m0, m1, m2 = zc * k0, zc * k1, zc * zc * k2
    a = [1 + m0, 3 + m0, 3 - m0, 1 - m0]
    b = [1 + (m1 + m2), 3 + (m1 - m2), 3 - (m1 + m2), 1 - (m1 - m2)]
    a = [x / b[0] for x in a]
    b = [x / b[0] for x in b]
    # divide numerator and denominator by (1 + z^-1)
    na = [a[0], a[1] - a[0]]; na.append(a[2] - na[1]); ra = a[3] - na[2]
    nb = [b[0], b[1] - b[0]]; nb.append(b[2] - nb[1]); rb = b[3] - nb[2]
    assert abs(ra) < 1e-12 and abs(rb) < 1e-12, (ra, rb)
    return dict(a0=na[0], a1=na[1], a2=na[2], b1=nb[1], b2=nb[2])


def injection(c1b, c2t, c2b, c3, c4, main=720000.0):
    cc, sc = main / 36.0, main / 18.0
    k0 = cc * c2t
    k1 = cc * ((c1b * c3 + c2t * c2t) / c2t)
    k2 = c2b
    zc = 2.0 * sc
    m = zc * k2
    b0 = k1 + m
    return dict(a0=(k0 + m) / b0, a1=(k0 - m) / b0, b1=(k1 - m) / b0)


def noise_shaper(c1, c2t, c2b, c3, c4, main=720000.0):
    cc, sc = main / 36.0, main / 18.0
    k0 = (c2t * c3 * c2b) / c4
    k1 = (c2t * c2b) * cc
    k2 = (c1 * c2t * c3) / (cc * c4)
    w0 = k2 ** -0.5
    wd = math.pi * sc
    if w0 > wd:
        w0 -= 2.0 * wd
    zc = w0 / math.tan(w0 / (2.0 * sc))
    m0, m1, m2 = zc * k0, zc * k1, zc * zc * k2
    b0 = 1 + m1 + m2
    return dict(a0=m0 / b0, a1=0.0, a2=-m0 / b0, b1=(2 - 2 * m2) / b0, b2=(1 - m1 + m2) / b0)


def lowpass(c1t, c1b, main=720000.0):
    cc, sc = main / 36.0, main / 18.0
    k = c1b / (cc * c1t) * (150.0 / 4000.0)
    w0 = 1.0 / k
    wd = math.pi * sc
    if w0 > wd:
        w0 -= 2.0 * wd
    zc = w0 / math.tan(w0 / (2.0 * sc))
    m = zc * k
    return dict(a0=1.0 / (1 + m), b1=(1 - m) / (1 + m))


def caps(value, values):
    return sum(c for i, c in enumerate(values) if (value >> i) & 1)


F1C = [2546, 4973, 9861, 19724]
F2V1 = [1390, 2965, 5875, 11297]
F2V2 = [833, 1663, 3164, 6327, 12654]
F3C = [2226, 4485, 9056, 18111]


def f1(f, main=720000.0):
    return standard(11247, 11797, 949, 52067, 2280 + caps(f, F1C), 166272, main)


def f2v(f2, q, main=720000.0):
    return standard(24840, 29154, 829 + caps(q, F2V1), 38180, 2352 + caps(f2, F2V2), 34270, main)


def f2n(f2, q, main=720000.0):
    return injection(29154, 829 + caps(q, F2V1), 38180, 2352 + caps(f2, F2V2), 34270, main)


def f3(f, main=720000.0):
    return standard(0, 17594, 868, 18828, 8480 + caps(f, F3C), 50019, main)


F4 = standard(0, 28810, 1165, 21457, 8558, 7289)
FX = lowpass(1122, 23131)
FN = noise_shaper(15500, 14854, 8450, 9523, 14083)
FN_GAIN = 1e4      # noise source amplitude of analog_calc, folded into FN.a0/a2
FN_SCALED = dict(FN, a0=FN["a0"] * FN_GAIN, a2=FN["a2"] * FN_GAIN)

# clock independence (the whole design relies on it)
for main in (398000.0, 1460000.0):
    for g, ref in ((f1(7, main), f1(7)), (f2v(19, 5, main), f2v(19, 5)), (f2n(3, 9, main), f2n(3, 9)),
                   (f3(11, main), f3(11)), (lowpass(1122, 23131, main), FX)):
        for k in ref:
            assert abs(g[k] - ref[k]) < 1e-9 * max(1, abs(ref[k])), (main, k, g[k], ref[k])


def q(x, frac=COEF_FRAC, bits=COEF_BITS):
    """round half away from zero - the same rule as llround() in the C model"""
    s = x * (1 << frac)
    v = int(math.floor(abs(s) + 0.5)) * (1 if s >= 0 else -1)
    lim = 1 << (bits - 1)
    assert -lim <= v < lim, (x, v)
    return v


DATA_FRAC = 18          # data word: 24 bit signed, 18 fractional bits (range [-32, 32))
GLOT = [0, -4 / 7.0, 7 / 7.0, 6 / 7.0, 5 / 7.0, 4 / 7.0, 3 / 7.0, 2 / 7.0, 1 / 7.0]

# ---- ROM layout (shared by VHDL and the fixed point model) --------------------
# ROM_F2, 4096 words: index = ((f2 << 4) | f2q) << 3 | k
#   k = 0..4  F2 voice biquad  a0, a1, a2, -b1, -b2
#   k = 5..7  F2 noise injection (1st order)  a0, a1, -b1
# ROM_MISC, 512 words:
MISC_F1, MISC_F3, MISC_F4, MISC_FN, MISC_FX = 0, 128, 256, 264, 272     # biquads: base + idx*8 + k
MISC_G15, MISC_GN2, MISC_GCL, MISC_GOUT, MISC_ONE = 288, 304, 320, 328, 329


def bq_words(c):
    return [q(c["a0"]), q(c["a1"]), q(c["a2"]), -q(c["b1"]), -q(c["b2"])]


def build_roms(t):
    f2 = [0] * 4096
    for i in range(512):
        w = bq_words(t["f2v"][i]) + [q(t["f2n"][i]["a0"]), q(t["f2n"][i]["a1"]), -q(t["f2n"][i]["b1"])]
        f2[i * 8:i * 8 + 8] = w
    misc = [0] * 512
    for i in range(16):
        misc[MISC_F1 + i * 8:MISC_F1 + i * 8 + 5] = bq_words(t["f1"][i])
        misc[MISC_F3 + i * 8:MISC_F3 + i * 8 + 5] = bq_words(t["f3"][i])
        misc[MISC_G15 + i] = q(i / 15.0)
        misc[MISC_GN2 + i] = q((5 + (15 ^ i)) / 20.0)
    misc[MISC_F4:MISC_F4 + 5] = bq_words(t["f4"])
    misc[MISC_FN:MISC_FN + 5] = bq_words(t["fn"])
    misc[MISC_FX:MISC_FX + 2] = [q(t["fx"]["a0"]), -q(t["fx"]["b1"])]
    for i in range(8):
        misc[MISC_GCL + i] = q((7 ^ i) / 7.0)
    misc[MISC_GOUT] = q(1.0 / 2.4)
    misc[MISC_ONE] = 1 << COEF_FRAC
    glot = [q(g, DATA_FRAC, 24) for g in GLOT]
    return f2, misc, glot


def tables():
    rom = read_rom()
    phones = [unpack_phone(rom, p) for p in range(64)]
    t = dict(phones=phones,
             f1=[f1(f) for f in range(16)],
             f2v=[f2v(f2, qq) for f2 in range(32) for qq in range(16)],
             f2n=[f2n(f2, qq) for f2 in range(32) for qq in range(16)],
             f3=[f3(f) for f in range(16)],
             f4=F4, fx=FX, fn=FN_SCALED)
    return t


def write_c(t, path):
    f2, misc, glot = build_roms(t)
    o = []
    o.append("/* GENERATED by tools/gen_votrax_tables.py - do not edit */")
    o.append("#define VT_COEF_FRAC %d" % COEF_FRAC)
    o.append("#define VT_DATA_FRAC %d" % DATA_FRAC)
    for n in ("MISC_F1", "MISC_F3", "MISC_F4", "MISC_FN", "MISC_FX", "MISC_G15", "MISC_GN2",
              "MISC_GCL", "MISC_GOUT", "MISC_ONE"):
        o.append("#define VT_%s %d" % (n, globals()[n]))
    o.append("typedef struct { int f1,va,f2,fc,f2q,f3,fa,cld,vd,closure,duration,pause; } vt_phone_t;")
    o.append("static const vt_phone_t VT_PHONE[64] = {")
    for p in t["phones"]:
        o.append("  {%(f1)d,%(va)d,%(f2)d,%(fc)d,%(f2q)d,%(f3)d,%(fa)d,%(cld)d,%(vd)d,%(closure)d,%(duration)d,%(pause)d}," % p)
    o.append("};")
    o.append("static const long long VT_ROM_F2[4096] = {")
    o += ["  " + ",".join(str(v) for v in f2[i:i + 8]) + "," for i in range(0, 4096, 8)]
    o.append("};")
    o.append("static const long long VT_ROM_MISC[512] = {")
    o += ["  " + ",".join(str(v) for v in misc[i:i + 8]) + "," for i in range(0, 512, 8)]
    o.append("};")
    o.append("static const long long VT_GLOTQ[9] = {" + ",".join(str(v) for v in glot) + "};")
    # double precision versions for the reference build of the model
    o.append("typedef struct { double a0,a1,a2,b1,b2; } vt_bq_t;")
    o.append("typedef struct { double a0,a1,b1; } vt_fo_t;")
    bq = lambda c: "{%.17g,%.17g,%.17g,%.17g,%.17g}" % (c["a0"], c["a1"], c["a2"], c["b1"], c["b2"])
    for name in ("f1", "f2v", "f3"):
        o.append("static const vt_bq_t VT_%s[%d] = {" % (name.upper(), len(t[name])))
        o += ["  " + bq(c) + "," for c in t[name]]
        o.append("};")
    o.append("static const vt_fo_t VT_F2N[512] = {")
    o += ["  {%.17g,%.17g,%.17g}," % (c["a0"], c["a1"], c["b1"]) for c in t["f2n"]]
    o.append("};")
    o.append("static const vt_bq_t VT_F4 = " + bq(t["f4"]) + ";")
    o.append("/* noise shaper, numerator already multiplied by the 1e4 noise amplitude */")
    o.append("static const vt_bq_t VT_FN = " + bq(t["fn"]) + ";")
    o.append("static const vt_fo_t VT_FX = {%.17g,0,%.17g};" % (t["fx"]["a0"], t["fx"]["b1"]))
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(o) + "\n")


def write_vhdl(t, path):
    f2, misc, glot = build_roms(t)
    o = []
    o.append("-- votrax_tables_pkg.vhd - GENERATED by sim/votrax/tools/gen_votrax_tables.py, do not edit.")
    o.append("--")
    o.append("-- Phoneme ROM of the Votrax SC-01 (unpacked from PinMAME src/sound/votrax.c, sc01_bin)")
    o.append("-- and the filter coefficients of PinMAME's SC-01 model, reduced to biquads and")
    o.append("-- quantised to %d bit (%d fractional bits). b coefficients are stored NEGATED, so the" % (COEF_BITS, COEF_FRAC))
    o.append("-- MAC only ever adds. Layout: see gen_votrax_tables.py (ROM_F2, ROM_MISC).")
    o.append("library ieee;")
    o.append("use ieee.std_logic_1164.all;")
    o.append("")
    o.append("package votrax_tables_pkg is")
    o.append("  constant VT_COEF_BITS : natural := %d;" % COEF_BITS)
    o.append("  constant VT_COEF_FRAC : natural := %d;" % COEF_FRAC)
    o.append("  constant VT_DATA_FRAC : natural := %d;" % DATA_FRAC)
    for n in ("MISC_F1", "MISC_F3", "MISC_F4", "MISC_FN", "MISC_FX", "MISC_G15", "MISC_GN2",
              "MISC_GCL", "MISC_GOUT", "MISC_ONE"):
        o.append("  constant VT_%s : natural := %d;" % (n, globals()[n]))
    o.append("")
    o.append("  type vt_phone_t is record")
    o.append("    f1, va, f2, fc, f2q, f3, fa, cld, vd : natural range 0 to 15;")
    o.append("    closure, pause : natural range 0 to 1;")
    o.append("    duration : natural range 0 to 127;")
    o.append("  end record;")
    o.append("  type vt_phone_rom_t is array (0 to 63) of vt_phone_t;")
    o.append("  constant VT_PHONE : vt_phone_rom_t := (")
    rows = []
    for i, p in enumerate(t["phones"]):
        rows.append("    %2d => (f1 => %d, va => %d, f2 => %d, fc => %d, f2q => %d, f3 => %d, fa => %d, "
                    "cld => %d, vd => %d, closure => %d, pause => %d, duration => %d)" % (
                        i, p["f1"], p["va"], p["f2"], p["fc"], p["f2q"], p["f3"], p["fa"], p["cld"],
                        p["vd"], p["closure"], p["pause"], p["duration"]))
    o.append(",\n".join(rows))
    o.append("  );")
    o.append("")
    lim = 2 ** (COEF_BITS - 1)
    o.append("  subtype vt_coef_t is integer range %d to %d;" % (-lim, lim - 1))
    o.append("  type vt_rom_f2_t is array (0 to 4095) of vt_coef_t;")
    o.append("  type vt_rom_misc_t is array (0 to 511) of vt_coef_t;")
    o.append("  type vt_glot_t is array (0 to 8) of integer;")

    def arr(name, typ, vals):
        o.append("  constant %s : %s := (" % (name, typ))
        lines = []
        for i in range(0, len(vals), 8):
            lines.append("    " + ", ".join("%d" % v for v in vals[i:i + 8]))
        o.append(",\n".join(lines))
        o.append("  );")

    arr("VT_ROM_F2", "vt_rom_f2_t", f2)
    arr("VT_ROM_MISC", "vt_rom_misc_t", misc)
    arr("VT_GLOT", "vt_glot_t", glot)
    o.append("end package votrax_tables_pkg;")
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(o) + "\n")


if __name__ == "__main__":
    t = tables()
    os.makedirs(os.path.join(SIM, "model"), exist_ok=True)
    write_c(t, os.path.join(SIM, "model", "votrax_tables.h"))
    vdir = os.path.join(ROOT, "rtl", "common", "votrax")
    os.makedirs(vdir, exist_ok=True)
    write_vhdl(t, os.path.join(vdir, "votrax_tables_pkg.vhd"))
    for name in ("f1", "f2v", "f3"):
        for k in ("a0", "a1", "a2", "b1", "b2"):
            vals = [c[k] for c in t[name]]
            print("%-4s %s  %+.6f .. %+.6f" % (name, k, min(vals), max(vals)))
    print("written: model/votrax_tables.h, rtl/common/votrax/votrax_tables_pkg.vhd")
