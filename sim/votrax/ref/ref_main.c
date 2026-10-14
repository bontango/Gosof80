/* ref_main.c - PinMAME's Votrax SC-01 emulation (Galibert core) as a command line
 * reference for the FPGA implementation.
 *
 * ../pinmame/votrax.c is included UNMODIFIED. This file provides the bits of the
 * MAME core it calls (see driver.h) and a tick based driver around it:
 *
 *   - time advances in main clock ticks (720 kHz nominal)
 *   - every 18 ticks one sample (main/18 = 40 kHz) is produced via Votrax_Update()
 *   - order inside one tick: (1) a CPU write scheduled for this tick, (2) due timers,
 *     (3) the sample if tick % 18 == 0
 *   - writes go through the same path as gts80s.c GTS80SS_vs_latch_w:
 *     votraxsc01_w(0, data ^ 0x3f) - the board inverts P0..P5, I1/I2 are D6/D7
 *   - the speech clock follows gts80s.c GTS80SS_da2_latch_w:
 *     votraxsc01_set_clock(max(-4500 + data * 5750, 1))
 *
 * Script (one command per line, '#' comments):
 *   clock <byte>        value written to $3000 (0x7E = 720 kHz, the normal speed)
 *   gap <ticks>         CPU reaction time between A/R going ready and the next write
 *   say <b> <b> ...     bus bytes written to $2000, each one waiting for A/R ready
 *   idle <ms>           let it run
 *   mute / unmute       a write to $7000 mutes, the next $2000 write unmutes (gts80s.c)
 *
 * Output: <out>.f32 raw float32 samples, <out>.wav 16 bit at 40 kHz (nominal rate),
 *         <out>.writes "tick byte" per write - the stimulus for the fixed point model
 *         and the VHDL testbench, so all three see the writes on the same tick.
 *
 * Build: gcc -O2 -I. -o ref_votrax ref_main.c -lm
 */
#include "driver.h"
#include "../pinmame/votrax.h"
#include "../pinmame/votrax.c"

#include <stdarg.h>

static UINT64 g_tick = 0;          /* current main clock tick */
static mame_timer g_timer;         /* votrax.c allocates exactly one */
static int g_busy = 0;             /* from BusyCallback: 1 while A/R is low */
static int g_volume = 100;
static float g_sample;
static int g_have_sample;

static FILE *f_raw, *f_wav, *f_wr;
static UINT32 g_nsamples = 0;
static float g_peak = 0;

/* ---- MAME core stand-ins ------------------------------------------------- */
mame_timer *timer_alloc(void (*cb)(int)) { memset(&g_timer, 0, sizeof g_timer); g_timer.callback = cb; return &g_timer; }
void timer_adjust(mame_timer *t, double d, int param, double period) {
    (void)period;
    t->param = param;
    if (d >= TIME_NEVER) { t->armed = 0; return; }
    t->armed = 1;
    /* seconds -> ticks at the current main clock */
    t->fire_at = (double)g_tick + (double)llround(d * (double)votraxsc01_locals.mainclock);
}
double timer_expire(mame_timer *t) { return t->armed ? t->fire_at : TIME_NEVER; }
int    timer_param(mame_timer *t)  { return t->param; }
void   timer_remove(mame_timer *t) { t->armed = 0; }
int  stream_init_float(const char *n, int l, double r, int p, void (*cb)(int, INT16 *, int), int f) { (void)n;(void)l;(void)r;(void)p;(void)cb;(void)f; return 0; }
void stream_set_sample_rate(int s, double r) { (void)s; (void)r; }
void stream_update(int s, int m) { (void)s; (void)m; }
void mixer_set_volume(int ch, int v) { (void)ch; g_volume = v; }
void logerror(const char *fmt, ...) { va_list a; va_start(a, fmt); vfprintf(stderr, fmt, a); va_end(a); }

static void busy_cb(int level) { g_busy = level; }

static struct VOTRAXSC01interface intf = { 1, {0}, {100}, {720000}, {busy_cb} };

/* ---- driver ------------------------------------------------------------- */
static void put_sample(float v) {
    fwrite(&v, sizeof v, 1, f_raw);
    if (fabsf(v) > g_peak) g_peak = fabsf(v);
    g_nsamples++;
}

static void one_tick(int write_byte) {
    if (write_byte >= 0) {
        votraxsc01_set_volume(100);                 /* GTS80SS_vs_latch_w */
        votraxsc01_w(0, write_byte ^ 0x3f);
        fprintf(f_wr, "%llu %02X\n", (unsigned long long)g_tick, write_byte);
    }
    if (g_timer.armed && g_timer.fire_at <= (double)g_tick) {
        g_timer.armed = 0;
        g_timer.callback(g_timer.param);
        /* the commit callback re-arms the timer for the end of phone; that one
           is always in the future, so a single check per tick is enough */
    }
    if (g_tick % 18 == 0) {
        float buf[1];
        Votrax_Update(0, (INT16 *)buf, 1);
        put_sample(g_volume ? buf[0] : 0.0f);
    }
    g_tick++;
}

static void run_ticks(UINT64 n) { while (n--) one_tick(-1); }

static void write_wav(const char *raw_name, const char *wav_name, float gain) {
    FILE *r = fopen(raw_name, "rb"), *w = fopen(wav_name, "wb");
    UINT32 n = g_nsamples, rate = 40000, br = rate * 2, sz = 36 + n * 2;
    UINT16 ch = 1, bps = 16, ba = 2, fmt = 1; UINT32 fl = 16;
    fwrite("RIFF", 1, 4, w); fwrite(&sz, 4, 1, w); fwrite("WAVEfmt ", 1, 8, w);
    fwrite(&fl, 4, 1, w); fwrite(&fmt, 2, 1, w); fwrite(&ch, 2, 1, w); fwrite(&rate, 4, 1, w);
    fwrite(&br, 4, 1, w); fwrite(&ba, 2, 1, w); fwrite(&bps, 2, 1, w);
    fwrite("data", 1, 4, w); sz = n * 2; fwrite(&sz, 4, 1, w);
    for (UINT32 i = 0; i < n; i++) {
        float v; if (fread(&v, sizeof v, 1, r) != 1) break;
        float s = v * gain * 32767.0f;
        if (s > 32767) s = 32767; if (s < -32768) s = -32768;
        INT16 o = (INT16)lrintf(s); fwrite(&o, 2, 1, w);
    }
    fclose(r); fclose(w);
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s script.txt outbase [wavgain]\n", argv[0]); return 2; }
    FILE *sc = fopen(argv[1], "r");
    if (!sc) { perror(argv[1]); return 1; }
    char nraw[512], nwav[512], nwr[512];
    snprintf(nraw, sizeof nraw, "%s.f32", argv[2]);
    snprintf(nwav, sizeof nwav, "%s.wav", argv[2]);
    snprintf(nwr,  sizeof nwr,  "%s.writes", argv[2]);
    f_raw = fopen(nraw, "wb"); f_wr = fopen(nwr, "w");
    float gain = argc > 3 ? (float)atof(argv[3]) : 0.0f;

    struct MachineSound ms = { &intf };
    VOTRAXSC01_sh_start(&ms);

    UINT64 gap = 36;   /* ~50 us at 720 kHz: NMI entry + handler until the store */
    char line[4096];
    while (fgets(line, sizeof line, sc)) {
        char *p = strchr(line, '#'); if (p) *p = 0;
        char cmd[32]; int off;
        if (sscanf(line, "%31s%n", cmd, &off) != 1) continue;
        p = line + off;
        if (!strcmp(cmd, "clock")) {
            int d = (int)strtol(p, NULL, 0);
            int f = -4500 + d * 5750; if (f < 1) f = 1;
            fprintf(f_wr, "%llu C%02X\n", (unsigned long long)g_tick, d);
            votraxsc01_set_clock((UINT32)f);
        } else if (!strcmp(cmd, "gap")) {
            gap = strtoull(p, NULL, 0);
        } else if (!strcmp(cmd, "idle")) {
            double ms_ = atof(p);
            run_ticks((UINT64)llround(ms_ * 1e-3 * votraxsc01_locals.mainclock));
        } else if (!strcmp(cmd, "mute")) {
            fprintf(f_wr, "%llu M\n", (unsigned long long)g_tick);
            votraxsc01_set_volume(0);
        } else if (!strcmp(cmd, "say")) {
            char *tok = strtok(p, " \t\r\n");
            while (tok) {
                int b = (int)strtol(tok, NULL, 16);
                while (votraxsc01_status_r(0)) one_tick(-1);   /* wait for A/R ready */
                run_ticks(gap);
                one_tick(b);
                tok = strtok(NULL, " \t\r\n");
            }
        } else {
            fprintf(stderr, "unknown command: %s\n", cmd); return 1;
        }
    }
    while (votraxsc01_status_r(0)) one_tick(-1);
    run_ticks(720000 / 10);                           /* 100 ms tail */
    fclose(f_raw); fclose(f_wr);
    if (gain <= 0) gain = g_peak > 0 ? 0.9f / g_peak : 1.0f;
    write_wav(nraw, nwav, gain);
    fprintf(stderr, "%u samples, %.3f s, peak %.5f, wav gain %.3f\n",
            g_nsamples, g_nsamples / 40000.0, g_peak, gain);
    return 0;
}
