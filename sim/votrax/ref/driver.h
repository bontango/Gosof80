/* driver.h - minimal stand-in for the PinMAME/MAME core, just enough to compile
 * the unmodified ../pinmame/votrax.c as a stand-alone reference.
 *
 * Time model: the harness (ref_main.c) advances in main clock ticks. Timers are
 * converted from seconds to ticks with llround(seconds * mainclock), so a timer set
 * to N/mainclock fires exactly N ticks later - which is what votrax.c means by
 * attotime::from_ticks(N, mainclock).
 */
#ifndef DRIVER_H_STUB
#define DRIVER_H_STUB

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef uint8_t  UINT8;
typedef int8_t   INT8;
typedef uint16_t UINT16;
typedef int16_t  INT16;
typedef uint32_t UINT32;
typedef int32_t  INT32;
typedef uint64_t UINT64;
typedef int64_t  INT64;

#define INLINE static inline
#define BIT(x,n) (((x) >> (n)) & 1)
#define CLEAR_LINE  0
#define ASSERT_LINE 1
#define TIME_NEVER  (1.0e30)

#define READ_HANDLER(name)  int  name(int offset)
#define WRITE_HANDLER(name) void name(int offset, int data)

struct MachineSound { const void *sound_interface; };

typedef struct mame_timer {
    void (*callback)(int);
    int    param;
    int    armed;
    double fire_at;      /* in seconds of harness time */
} mame_timer;

/* provided by ref_main.c */
mame_timer *timer_alloc(void (*callback)(int));
void   timer_adjust(mame_timer *t, double duration, int param, double period);
double timer_expire(mame_timer *t);
int    timer_param(mame_timer *t);
void   timer_remove(mame_timer *t);
int    stream_init_float(const char *name, int level, double rate, int param,
                         void (*cb)(int, INT16 *, int), int is_float);
void   stream_set_sample_rate(int stream, double rate);
void   stream_update(int stream, int min_interval);
void   mixer_set_volume(int ch, int volume);
void   logerror(const char *fmt, ...);

#endif
