#include <fenv.h>
#include <stddef.h>

#include "fp_machine.h"

#define REQUIRE(condition, status) do { if (!(condition)) return (status); } while (0)
enum { X87_MASKS = 0x003f, X87_ROUNDING = 0x0c00, MXCSR_MASKS = 0x1f80, MXCSR_ROUNDING = 0x6000 };

struct x87_image {
    unsigned short control, reserved0, status, reserved1;
    unsigned char rest[20];
};

_Static_assert(sizeof(struct x87_image) == 28 && sizeof(fenv_t) == 32,
               "the x86 environment uses the 28-byte x87 image and MXCSR");

static void seed(unsigned mode, unsigned x87_flags, unsigned sse_flags, int unmask_invalid)
{
    struct x87_image image;
    __asm__ volatile("fnclex; fnstenv %0" : "=m"(image));
    image.control = (unsigned short)((image.control & ~X87_ROUNDING) | X87_MASKS | mode);
    image.status = (unsigned short)((image.status & ~X87_MASKS) | x87_flags);
    unsigned mxcsr = MXCSR_MASKS | (mode << 3) | sse_flags;
    if (unmask_invalid) {
        image.control &= (unsigned short)~1u;
        mxcsr &= ~0x80u;
    }
    __asm__ volatile("fldenv %0; ldmxcsr %1" : : "m"(image), "m"(mxcsr) : "memory");
}

static unsigned flags(struct machine_fenv state)
{
    return (state.status | state.mxcsr) & FE_ALL_EXCEPT;
}

static int same_controls(struct machine_fenv a, struct machine_fenv b)
{
    return a.control == b.control && ((a.mxcsr ^ b.mxcsr) & ~0x3fu) == 0;
}

static unsigned short word(const void *storage, size_t offset)
{
    const unsigned char *bytes = storage;
    return (unsigned short)(bytes[offset] | (unsigned int)bytes[offset + 1] << 8);
}

static unsigned int doubleword(const void *storage, size_t offset)
{
    return word(storage, offset) | (unsigned int)word(storage, offset + 2) << 16;
}

static int rounding(void)
{
    seed(FE_DOWNWARD, FE_DIVBYZERO, FE_INEXACT, 1);
    REQUIRE(fegetround() == FE_DOWNWARD, 30);
    struct machine_fenv initial = observe();
    static const int modes[] = {FE_UPWARD, FE_TOWARDZERO, FE_TONEAREST, FE_DOWNWARD};
    for (size_t i = 0; i < sizeof modes / sizeof modes[0]; ++i) {
        int mode = modes[i];
        REQUIRE(fesetround(mode) == 0, 31);
        struct machine_fenv actual = observe();
        REQUIRE((actual.control & X87_ROUNDING) == mode
                && (actual.mxcsr & MXCSR_ROUNDING) == (unsigned int)mode << 3, 31);
        REQUIRE(((actual.control ^ initial.control) & ~X87_ROUNDING) == 0
                && ((actual.mxcsr ^ initial.mxcsr) & ~MXCSR_ROUNDING) == 0
                && (actual.status & FE_ALL_EXCEPT) == (initial.status & FE_ALL_EXCEPT), 32);
        REQUIRE(fegetround() == mode, 33);
    }
    struct machine_fenv before = observe();
    REQUIRE(fesetround(0x0c01) != 0, 34);
    struct machine_fenv after = observe();
    REQUIRE(same_controls(before, after) && flags(before) == flags(after), 35);
    return 0;
}

static int exceptions(void)
{
    seed(FE_UPWARD, FE_INVALID | FE_INEXACT, FE_DIVBYZERO | FE_OVERFLOW, 0);
    struct machine_fenv before = observe();
    REQUIRE(fetestexcept(FE_ALL_EXCEPT) == (FE_INVALID | FE_INEXACT | FE_DIVBYZERO | FE_OVERFLOW)
            && fetestexcept(FE_DIVBYZERO | FE_UNDERFLOW) == FE_DIVBYZERO, 40);
    REQUIRE(feclearexcept(FE_INVALID | FE_OVERFLOW) == 0, 41);
    struct machine_fenv after = observe();
    REQUIRE(flags(after) == (FE_INEXACT | FE_DIVBYZERO) && same_controls(before, after), 42);
    REQUIRE(feclearexcept(0) == 0 && flags(observe()) == flags(after), 43);
    REQUIRE(feclearexcept(FE_ALL_EXCEPT) == 0 && !flags(observe()), 44);
    return 0;
}

static int saved_flags(void)
{
    seed(FE_DOWNWARD, FE_DIVBYZERO, FE_INVALID | FE_INEXACT, 0);
    struct machine_fenv before = observe();
    fexcept_t saved = (fexcept_t)0xa55a;
    const int selected = FE_DIVBYZERO | FE_INVALID | FE_OVERFLOW;
    REQUIRE(fegetexceptflag(&saved, selected) == 0, 50);
    REQUIRE(saved == (FE_DIVBYZERO | FE_INVALID) && flags(observe()) == flags(before), 51);
    seed(FE_UPWARD, FE_INEXACT, FE_OVERFLOW, 0);
    before = observe();
    REQUIRE(fesetexceptflag(&saved, selected) == 0, 52);
    struct machine_fenv after = observe();
    REQUIRE(flags(after) == (FE_DIVBYZERO | FE_INVALID | FE_INEXACT)
            && same_controls(before, after), 53);
    return 0;
}

static int save_restore(void)
{
    seed(FE_UPWARD, FE_DIVBYZERO, FE_INEXACT, 1);
    struct machine_fenv before = observe();
    fenv_t saved = {0};
    REQUIRE(fegetenv(&saved) == 0, 54);
    struct machine_fenv after = observe();
    REQUIRE(word(&saved, 0) == before.control && word(&saved, 4) == before.status
            && doubleword(&saved, 28) == before.mxcsr && same_controls(before, after)
            && flags(before) == flags(after), 55);
    seed(FE_DOWNWARD, 0, 0, 0);
    REQUIRE(fesetenv(&saved) == 0, 56);
    after = observe();
    REQUIRE(same_controls(before, after) && flags(before) == flags(after), 57);
    REQUIRE(fesetenv(FE_DFL_ENV) == 0, 58);
    after = observe();
    REQUIRE((after.control & (X87_MASKS | X87_ROUNDING)) == X87_MASKS
            && (after.mxcsr & (MXCSR_MASKS | MXCSR_ROUNDING)) == MXCSR_MASKS
            && !flags(after), 59);
    return 0;
}

static int hold_update(void)
{
    seed(FE_DOWNWARD, FE_DIVBYZERO, FE_INEXACT, 1);
    struct machine_fenv before = observe();
    fenv_t saved = {0};
    REQUIRE(feholdexcept(&saved) == 0, 60);
    struct machine_fenv held = observe();
    REQUIRE(!flags(held) && (held.control & (X87_MASKS | X87_ROUNDING)) == (X87_MASKS | FE_DOWNWARD)
            && (held.mxcsr & (MXCSR_MASKS | MXCSR_ROUNDING)) == (MXCSR_MASKS | (FE_DOWNWARD << 3)), 61);
    REQUIRE(word(&saved, 0) == before.control && word(&saved, 4) == before.status
            && doubleword(&saved, 28) == before.mxcsr, 62);
    REQUIRE(feraiseexcept(FE_OVERFLOW) == 0 && (flags(observe()) & FE_OVERFLOW), 63);
    REQUIRE(feupdateenv(&saved) == 0, 64);
    struct machine_fenv after = observe();
    REQUIRE(same_controls(before, after) && flags(after) == (FE_DIVBYZERO | FE_OVERFLOW | FE_INEXACT), 65);
    return 0;
}

static int raise_flags(void)
{
    static const int exceptions[] = {FE_INVALID, FE_DIVBYZERO, FE_OVERFLOW, FE_UNDERFLOW, FE_INEXACT};
    for (size_t i = 0; i < sizeof exceptions / sizeof exceptions[0]; ++i) {
        seed(FE_TOWARDZERO, 0, 0, 0);
        struct machine_fenv before = observe();
        int exception = exceptions[i];
        REQUIRE(feraiseexcept(exception) == 0, 70);
        struct machine_fenv after = observe();
        unsigned allowed = (unsigned int)exception;
        if (exception == FE_OVERFLOW || exception == FE_UNDERFLOW)
            allowed |= FE_INEXACT;
        REQUIRE((flags(after) & (unsigned int)exception) && !(flags(after) & ~allowed)
                && same_controls(before, after), 71);
    }
    return 0;
}

static int equal(const char *a, const char *b)
{
    while (*a && *a == *b) {
        ++a;
        ++b;
    }
    return *a == *b;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 9);
    struct machine_fenv original = observe();
    int status = 10;
    if (equal(argv[1], "rounding"))
        status = rounding();
    else if (equal(argv[1], "exceptions"))
        status = exceptions();
    else if (equal(argv[1], "flags"))
        status = saved_flags();
    else if (equal(argv[1], "restore"))
        status = save_restore();
    else if (equal(argv[1], "hold"))
        status = hold_update();
    else if (equal(argv[1], "raise"))
        status = raise_flags();
    install(original.control, original.mxcsr);
    return status;
}
