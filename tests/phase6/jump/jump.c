#include "../kernel_abi.h"
#include <setjmp.h>
#include <signal.h>
#include <stdint.h>

#ifndef OA_PHASE6_HOST
_Static_assert(sizeof(jmp_buf) == 64 && _Alignof(jmp_buf) == 8, "project jmp_buf layout");
_Static_assert(sizeof(sigjmp_buf) == 200 && _Alignof(sigjmp_buf) == 8, "project sigjmp_buf layout");
#endif

struct control_state {
    unsigned short cw;
    unsigned int mxcsr;
};

static struct control_state control(void)
{
    struct control_state state;
    __asm__ volatile("fnstcw %0" : "=m"(state.cw));
    __asm__ volatile("stmxcsr %0" : "=m"(state.mxcsr));
    return state;
}

static void set_control(struct control_state state)
{
    __asm__ volatile("fldcw %0; ldmxcsr %1" : : "m"(state.cw), "m"(state.mxcsr) : "memory");
}

static int same_control(struct control_state expected)
{
    struct control_state got = control();
    return got.cw == expected.cw && (got.mxcsr & ~0x3fu) == (expected.mxcsr & ~0x3fu);
}

static struct control_state downward(struct control_state state)
{
    state.cw = (unsigned short)((state.cw & ~0xc00u) | 0x400u);
    state.mxcsr = (state.mxcsr & ~0x6000u) | 0x2000u;
    return state;
}

static uint64_t bit(int number)
{
    return UINT64_C(1) << (number - 1);
}

static long current_mask(uint64_t *old)
{
    return kernel_call(__NR_rt_sigprocmask, SIG_SETMASK, 0, (long)old, 8, 0, 0);
}

static long change_mask(uint64_t next)
{
    return kernel_call(__NR_rt_sigprocmask, SIG_SETMASK, (long)&next, 0, 8, 0, 0);
}

static int mask_is(uint64_t wanted)
{
    uint64_t value = 0;
    return current_mask(&value) == 0 && value == wanted;
}

static void fill(void *storage, size_t size)
{
    unsigned char *bytes = storage;
    for (size_t i = 0; i < size; ++i)
        bytes[i] = 0xa5;
}

static int unchanged(const void *storage, size_t size)
{
    const unsigned char *bytes = storage;
    for (size_t i = 0; i < size; ++i) {
        if (bytes[i] != 0xa5)
            return 0;
    }
    return 1;
}

static int setjmp_case(void)
{
    struct {
        uint64_t before;
        jmp_buf context;
        uint64_t after;
    } box;
    fill(&box, sizeof box);
    struct control_state before = control();
    const uint64_t mask = bit(SIGUSR1);
    if (change_mask(mask))
        return 10;
    errno = TEST_ERRNO;
    switch (setjmp(box.context)) {
    case 0:
        if (unchanged(&box.context, sizeof box.context) ||
            !unchanged(&box.before, sizeof box.before) || !unchanged(&box.after, sizeof box.after))
            return 11;
        break;
    default: return 12;
    }
    return !mask_is(mask) || !same_control(before) || errno != TEST_ERRNO ? 13 : 0;
}

static int sigsetjmp_case(void)
{
    struct {
        uint64_t before;
        sigjmp_buf context;
        uint64_t after;
    } box;
    fill(&box, sizeof box);
    struct control_state before = control();
    const uint64_t mask = bit(SIGUSR1) | bit(SIGUSR2);
    if (change_mask(mask))
        return 20;
    errno = TEST_ERRNO;
    switch (sigsetjmp(box.context, 9)) {
    case 0:
        if (unchanged(&box.context, sizeof box.context) ||
            !unchanged(&box.before, sizeof box.before) || !unchanged(&box.after, sizeof box.after))
            return 21;
        break;
    default: return 22;
    }
#ifndef OA_PHASE6_HOST
    const unsigned char *bytes = (const unsigned char *)&box.context;
    uint64_t saved = 0;
    for (unsigned i = 0; i < 8; ++i)
        saved |= (uint64_t)bytes[72 + i] << (8 * i);
    if (bytes[64] != 1 || saved != mask)
        return 23;
    for (unsigned i = 65; i < 72; ++i) {
        if (bytes[i])
            return 24;
    }
    for (unsigned i = 80; i < sizeof box.context; ++i) {
        if (bytes[i])
            return 25;
    }
#endif
    return !mask_is(mask) || !same_control(before) || errno != TEST_ERRNO ? 26 : 0;
}

static __attribute__((noinline)) _Noreturn void nested_jump(jmp_buf context, int value)
{
    volatile int nested = value;
    longjmp(context, nested);
}

static int longjmp_case(void)
{
    jmp_buf outer, inner;
    volatile int stage = 0;
    const uint64_t initial_mask = bit(SIGUSR1), current = bit(SIGUSR2);
    struct control_state initial = control(), changed = downward(initial);
    if (change_mask(initial_mask))
        return 30;
    switch (setjmp(outer)) {
    case 0:
        switch (setjmp(inner)) {
        case 0:
            stage = 1;
            if (change_mask(current))
                return 31;
            set_control(changed);
            nested_jump(inner, 0);
        case 1:
            if (stage != 1 || !mask_is(current) || !same_control(changed))
                return 32;
            stage = 2;
            nested_jump(outer, -37);
        default: return 33;
        }
    case -37:
        if (stage != 2 || !mask_is(current) || !same_control(changed))
            return 34;
        set_control(initial);
        return raw_write(STDOUT_FILENO, "J\n", 2) == 2 ? 0 : 35;
    default: return 36;
    }
}

static __attribute__((noinline)) _Noreturn void nested_sigjump(sigjmp_buf context, int value)
{
    volatile int nested = value;
    siglongjmp(context, nested);
}

static int siglongjmp_case(int save)
{
    sigjmp_buf context;
    volatile int stage = 0;
    const uint64_t saved = bit(SIGUSR1), current = bit(SIGUSR2);
    struct control_state initial = control(), changed = downward(initial);
    if (change_mask(saved))
        return 40;
    switch (sigsetjmp(context, save)) {
    case 0:
        stage = 17;
        if (change_mask(current))
            return 41;
        set_control(changed);
        nested_sigjump(context, save ? 0 : -53);
    case 1:
        if (!save)
            return 42;
        break;
    case -53:
        if (save)
            return 43;
        break;
    default: return 44;
    }
    if (stage != 17 || !mask_is(save ? saved : current) || !same_control(changed))
        return 45;
    set_control(initial);
    return raw_write(STDOUT_FILENO, "S\n", 2) == 2 ? 0 : 46;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "setjmp")) return setjmp_case();
    if (same_text(mode, "sigsetjmp")) return sigsetjmp_case();
    if (same_text(mode, "longjmp")) return longjmp_case();
    if (same_text(mode, "siglongjmp")) return siglongjmp_case(1);
    if (same_text(mode, "siglongjmp-nosave")) return siglongjmp_case(0);
    return 2;
}
