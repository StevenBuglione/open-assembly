; Use an AVX instruction on the SSE2 baseline.
bits 64
default rel

section .text
global seed_avx_instruction:function
seed_avx_instruction:
    vpxor xmm0, xmm0, xmm0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
