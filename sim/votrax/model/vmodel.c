/* vmodel.c - model of the FPGA Votrax SC-01 (rtl/common/votrax/votrax_sc01.vhd).
 *
 * This file is the SPECIFICATION of the VHDL module: same tick based control, same
 * order of operations, same fixed point arithmetic. Two builds:
 *
 *   -DVT_FIXED   bit exact golden model for the VHDL testbench (writes .txt with one
 *                16 bit sample per line, and .f32 for listening/comparison)
 *   (default)    the same structure in double precision; prints the value range of
 *                every stored signal (to size the fixed point words) and writes .f32
 *
 * Control logic is a transcription of PinMAME votrax.c (phone_commit, chip_update,
 * interpolate, filters_commit, votraxsc01_w, the two timer events). The filters are
 * the biquads that votrax.c's "3rd order" filters reduce to (gen_votrax_tables.py).
 *
 * Input: the .writes file produced by ref_votrax ("tick byte", "tick Cxx", "tick M"),
 * so model and reference see every write on the same main clock tick.
 *
 * Build: gcc -O2 -o vmodel_dbl vmodel.c -lm ; gcc -O2 -DVT_FIXED -o vmodel_fix vmodel.c -lm
 * Run:   vmodel_fix ref_t1.writes out_base total_ticks
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "votrax_tables.h"

/* ---- fixed point formats ------------------------------------------------- */
/* coefficients: 27 bit signed, VT_COEF_FRAC (24) fractional bits, from the ROMs   */
/* data:         24 bit signed, VT_DATA_FRAC (18) fractional bits, range [-32, 32) */
#define CF VT_COEF_FRAC
#define DW 24
#define DF VT_DATA_FRAC
#define OUT_SHIFT (DF - 13)   /* output: 1.0 = 8192 in the 16 bit sample */

#ifdef VT_FIXED
typedef int64_t val_t;
static int64_t sat_count = 0;
static val_t sat(int64_t v) {
    const int64_t hi = (1LL << (DW - 1)) - 1, lo = -(1LL << (DW - 1));
    if (v > hi) { sat_count++; return hi; }
    if (v < lo) { sat_count++; return lo; }
    return v;
}
/* end of one MAC operation: round the accumulator back to the data format, saturate */
static val_t mac_end(int64_t acc) { return sat((acc + (1LL << (CF - 1))) >> CF); }
#define M(i) VT_ROM_MISC[i]
#else
typedef double val_t;
static const double GLOT[9] = { 0, -4/7.0, 7/7.0, 6/7.0, 5/7.0, 4/7.0, 3/7.0, 2/7.0, 1/7.0 };
#endif

/* ---- chip state (names as in votrax.c) ----------------------------------- */
static int inflection, phone;
static int ar_state = 1;
static int rom_duration, rom_vd, rom_cld, rom_fa, rom_fc, rom_va, rom_f1, rom_f2, rom_f2q, rom_f3;
static int rom_closure, rom_pause;
static int cur_fa, cur_fc, cur_va, cur_f1, cur_f2, cur_f2q, cur_f3;     /* 8 bit */
static int filt_fa, filt_fc, filt_va, filt_f1, filt_f2, filt_f2q, filt_f3;
static int phonetick, ticks, pitch, closure, update_counter, cur_closure;
static int noise, cur_noise;
static uint32_t sample_count;
static int muted;
static long mainclock = 720000;               /* only to detect real clock changes */

/* the one timer of votrax.c */
enum { T_NONE, T_COMMIT_PHONE, T_END_OF_PHONE };
static int timer_kind = T_NONE;
static uint64_t timer_at;

static void phone_commit(void) {
    phonetick = 0; ticks = 0;
    const vt_phone_t *p = &VT_PHONE[phone];
    rom_f1 = p->f1; rom_va = p->va; rom_f2 = p->f2; rom_fc = p->fc; rom_f2q = p->f2q;
    rom_f3 = p->f3; rom_fa = p->fa; rom_cld = p->cld; rom_vd = p->vd;
    rom_closure = p->closure; rom_duration = p->duration; rom_pause = p->pause;
    if (rom_cld == 0) cur_closure = rom_closure;
}

static void interpolate(int *reg, int target) { *reg = (*reg - (*reg >> 3) + (target << 1)) & 0xff; }

static void filters_commit(void) {
    filt_fa = cur_fa >> 4; filt_fc = cur_fc >> 4; filt_va = cur_va >> 4;
    filt_f1 = cur_f1 >> 4; filt_f2 = cur_f2 >> 3; filt_f2q = cur_f2q >> 4; filt_f3 = cur_f3 >> 4;
}

static void chip_update(void) {
    if (ticks != 0x10) {
        phonetick = (phonetick + 1) & 0x1ff;
        if (phonetick == ((rom_duration << 2) | 1)) {
            phonetick = 0; ticks++;
            if (ticks == rom_cld) cur_closure = rom_closure;
        }
    }
    update_counter++;
    if (update_counter == 0x30) update_counter = 0;
    int tick_625 = !(update_counter & 0xf);
    int tick_208 = (update_counter == 0x28);
    if (tick_208 && (!rom_pause || !(filt_fa || filt_va))) {
        interpolate(&cur_fc, rom_fc); interpolate(&cur_f1, rom_f1); interpolate(&cur_f2, rom_f2);
        interpolate(&cur_f2q, rom_f2q); interpolate(&cur_f3, rom_f3);
    }
    if (tick_625) {
        if (ticks >= rom_vd)  interpolate(&cur_fa, rom_fa);
        if (ticks >= rom_cld) interpolate(&cur_va, rom_va);
    }
    if (!cur_closure && (filt_fa || filt_va)) closure = 0;
    else if (closure != (7 << 2)) closure++;
    pitch = (pitch + 1) & 0xff;
    if (pitch == ((0xe0 ^ (inflection << 5) ^ (filt_f1 << 1)) + 2)) pitch = 0;
    if ((pitch & 0xf9) == 0x08) filters_commit();
    int inp = cur_noise && (noise != 0x7fff);
    noise = ((noise << 1) & 0x7ffe) | inp;
    cur_noise = !(((noise >> 14) ^ (noise >> 13)) & 1);
}

/* ---- analog path (analog_calc of votrax.c, as MAC operations) -------------- */
typedef struct { val_t x[3], y[2]; } bq_state;          /* x0 newest input, y0 last output */
static bq_state s_f1, s_f2v, s_fn, s_f3, s_f4;
static val_t f2n_x[2], f2n_y, fx_y;

#ifndef VT_FIXED
static double vmax[16]; static const char *vname[16];
static void track(int i, const char *n, double v) { vname[i] = n; if (fabs(v) > vmax[i]) vmax[i] = fabs(v); }
#else
#define track(i, n, v) ((void)0)
#endif

#ifdef VT_FIXED
/* c = 5 ROM words: a0, a1, a2, -b1, -b2 */
static val_t biquad(bq_state *s, val_t in, const long long *c) {
    s->x[2] = s->x[1]; s->x[1] = s->x[0]; s->x[0] = in;
    val_t y = mac_end(c[0] * s->x[0] + c[1] * s->x[1] + c[2] * s->x[2] + c[3] * s->y[0] + c[4] * s->y[1]);
    s->y[1] = s->y[0]; s->y[0] = y;
    return y;
}
#define GAIN(base, i, d) mac_end(M((base) + (i)) * (int64_t)(d))
#else
static val_t biquad(bq_state *s, val_t in, const vt_bq_t *c) {
    s->x[2] = s->x[1]; s->x[1] = s->x[0]; s->x[0] = in;
    val_t y = c->a0 * s->x[0] + c->a1 * s->x[1] + c->a2 * s->x[2] - c->b1 * s->y[0] - c->b2 * s->y[1];
    s->y[1] = s->y[0]; s->y[0] = y;
    return y;
}
#endif

static val_t analog_calc(void) {
    int gi = pitch >= (9 << 3) ? 0 : (pitch >> 3);
    int ns_pos = (pitch & 0x40) ? cur_noise : 0;
    int f2i = (filt_f2 << 4) | filt_f2q;
    val_t v, n, n2, vn, out;
#ifdef VT_FIXED
    /* 1. pitch wave x va/15            */ v  = GAIN(VT_MISC_G15, filt_va, VT_GLOTQ[gi]);
    /* 3. F1                            */ v  = biquad(&s_f1, v, &M(VT_MISC_F1 + filt_f1 * 8));
    /* 4. F2 voice                      */ v  = biquad(&s_f2v, v, &VT_ROM_F2[f2i * 8]);
    /* 5. noise +-1 x fa/15             */ n  = GAIN(VT_MISC_G15, filt_fa, ns_pos ? (1LL << DF) : -(1LL << DF));
    /* 6. noise shaper (x1e4 inside)    */ n  = biquad(&s_fn, n, &M(VT_MISC_FN));
    /* 7. x fc/15                       */ n2 = GAIN(VT_MISC_G15, filt_fc, n);
    /* 8. F2 noise injection, 1st order */
    f2n_x[1] = f2n_x[0]; f2n_x[0] = n2;
    {   const long long *c = &VT_ROM_F2[f2i * 8 + 5];
        n2 = f2n_y = mac_end(c[0] * f2n_x[0] + c[1] * f2n_x[1] + c[2] * f2n_y); }
    /* 9. v + n2                        */ vn = mac_end(M(VT_MISC_ONE) * v + M(VT_MISC_ONE) * n2);
    /* 10. F3                           */ vn = biquad(&s_f3, vn, &M(VT_MISC_F3 + filt_f3 * 8));
    /* 11. + n x (5 + (15^fc))/20       */ vn = mac_end(M(VT_MISC_ONE) * vn + M(VT_MISC_GN2 + filt_fc) * n);
    /* 12. F4                           */ vn = biquad(&s_f4, vn, &M(VT_MISC_F4));
    /* 13. glottal closure (7^cl)/7     */ vn = GAIN(VT_MISC_GCL, closure >> 2, vn);
    /* 14. final low pass               */ fx_y = mac_end(M(VT_MISC_FX) * vn + M(VT_MISC_FX + 1) * fx_y);
    /* 15. x 1/2.4                      */ out = GAIN(VT_MISC_GOUT, 0, fx_y);
#else
    v = GLOT[gi] * filt_va / 15.0;                                  track(0, "v_in", v);
    v = biquad(&s_f1, v, &VT_F1[filt_f1]);                          track(1, "f1", v);
    v = biquad(&s_f2v, v, &VT_F2V[f2i]);                            track(2, "f2v", v);
    n = (ns_pos ? 1.0 : -1.0) * filt_fa / 15.0;                     track(3, "n_in", n);
    n = biquad(&s_fn, n, &VT_FN);                                   track(4, "fn", n);
    n2 = n * filt_fc / 15.0;                                        track(5, "n2_in", n2);
    f2n_x[1] = f2n_x[0]; f2n_x[0] = n2;
    n2 = f2n_y = VT_F2N[f2i].a0 * f2n_x[0] + VT_F2N[f2i].a1 * f2n_x[1] - VT_F2N[f2i].b1 * f2n_y;
                                                                    track(6, "f2n", n2);
    vn = v + n2;                                                    track(7, "vn_in", vn);
    vn = biquad(&s_f3, vn, &VT_F3[filt_f3]);                        track(8, "f3", vn);
    vn = vn + n * (5 + (15 ^ filt_fc)) / 20.0;                      track(9, "f4_in", vn);
    vn = biquad(&s_f4, vn, &VT_F4);                                 track(10, "f4", vn);
    vn = vn * (7 ^ (closure >> 2)) / 7.0;                           track(11, "cl", vn);
    fx_y = VT_FX.a0 * vn - VT_FX.b1 * fx_y;                         track(12, "fx", fx_y);
    out = fx_y / 2.4;                                               track(13, "out", out);
#endif
    return out;
}

/* ---- driver: same tick order as ref_main.c -------------------------------- */
static void do_write(int bus) {
    muted = 0;                                   /* a $2000 write unmutes */
    int data = bus ^ 0x3f;
    inflection = (data >> 6) & 3;
    phone = data & 0x3f;
    ar_state = 0;
}

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s in.writes outbase total_ticks\n", argv[0]); return 2; }
    FILE *w = fopen(argv[1], "r"); if (!w) { perror(argv[1]); return 1; }
    char n1[512], n2[512];
    snprintf(n1, sizeof n1, "%s.f32", argv[2]); snprintf(n2, sizeof n2, "%s.txt", argv[2]);
    FILE *fo = fopen(n1, "wb");
#ifdef VT_FIXED
    FILE *ft = fopen(n2, "w");
#endif
    uint64_t total = strtoull(argv[3], NULL, 0);

    /* VOTRAXSC01_sh_start */
    phone = 0x3f; inflection = 0; ar_state = 1; sample_count = 0;
    phone_commit();
    cur_fa = cur_fc = cur_va = cur_f1 = cur_f2 = cur_f2q = cur_f3 = 0;
    filters_commit();
    pitch = 0; closure = 0; update_counter = 0; cur_closure = 1; noise = 0; cur_noise = 0;

    uint64_t next_tick = 0; char kind[16]; unsigned long long wt; int have = 0;
    have = fscanf(w, "%llu %15s", &wt, kind) == 2;
    uint64_t nsamp = 0;

    for (uint64_t t = 0; t < total; t++) {
        /* (1) stimulus events of this tick, in file order */
        while (have && wt == t) {
            if (kind[0] == 'C') {
                /* votraxsc01_set_clock: only on a real change, then filters_commit(0) */
                int d = (int)strtol(kind + 1, NULL, 16);
                long f = -4500L + d * 5750L; if (f < 1) f = 1;
                if (f != mainclock) { mainclock = f; filters_commit(); }
            }
            else if (kind[0] == 'M') muted = 1;
            else {
                do_write((int)strtol(kind, NULL, 16));
                if (timer_kind != T_COMMIT_PHONE) { timer_kind = T_COMMIT_PHONE; timer_at = t + 72; }
            }
            have = fscanf(w, "%llu %15s", &wt, kind) == 2;
        }
        /* (2) timer */
        if (timer_kind != T_NONE && timer_at <= t) {
            if (timer_kind == T_COMMIT_PHONE) {
                phone_commit();
                timer_kind = T_END_OF_PHONE;
                timer_at = t + (uint64_t)(16 * (rom_duration * 4 + 1) * 4 * 9 + 2);
            } else { timer_kind = T_NONE; ar_state = 1; }
        }
        /* (3) one sample every 18 ticks */
        if (t % 18 == 0) {
            sample_count++;
            if (sample_count & 1) chip_update();
            val_t o = analog_calc();
            if (muted) o = 0;
#ifdef VT_FIXED
            int64_t s16 = o >> OUT_SHIFT;                 /* already rounded by the MAC */
            if (s16 > 32767) s16 = 32767; if (s16 < -32768) s16 = -32768;
            fprintf(ft, "%lld\n", (long long)s16);
            float f = (float)s16 / 8192.0f;
#else
            float f = (float)o;
#endif
            fwrite(&f, sizeof f, 1, fo);
            nsamp++;
        }
        (void)next_tick;
    }
    fclose(fo);
#ifdef VT_FIXED
    fclose(ft);
    fprintf(stderr, "%llu samples, saturations: %lld\n", (unsigned long long)nsamp, (long long)sat_count);
#else
    fprintf(stderr, "%llu samples. max |value|:\n", (unsigned long long)nsamp);
    for (int i = 0; i < 14; i++) fprintf(stderr, "  %-6s %10.4f\n", vname[i], vmax[i]);
#endif
    return 0;
}
