#ifndef AL_PHASE5_FP_MACHINE_H
#define AL_PHASE5_FP_MACHINE_H

struct machine_fenv {
    unsigned short control, status;
    unsigned int mxcsr;
};

static inline struct machine_fenv observe(void)
{
    struct machine_fenv state;
    __asm__ volatile("fnstcw %0" : "=m"(state.control));
    __asm__ volatile("fnstsw %0" : "=m"(state.status));
    __asm__ volatile("stmxcsr %0" : "=m"(state.mxcsr));
    return state;
}

static inline void install(unsigned short control, unsigned int mxcsr)
{
    __asm__ volatile("fnclex; fldcw %0; ldmxcsr %1" : : "m"(control), "m"(mxcsr) : "memory");
}

#endif
