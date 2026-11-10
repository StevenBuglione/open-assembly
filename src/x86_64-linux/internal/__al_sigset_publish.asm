; Original Linux signal mask expansion. rdi = public mask, rsi = kernel word.
bits 64
default rel

global __al_sigset_publish:function

section .text.__al_sigset_publish alloc exec nowrite progbits
__al_sigset_publish:
    mov [rdi], rsi
    pxor xmm0, xmm0
    movdqu [rdi + 8], xmm0
    movdqu [rdi + 24], xmm0
    movdqu [rdi + 40], xmm0
    movdqu [rdi + 56], xmm0
    movdqu [rdi + 72], xmm0
    movdqu [rdi + 88], xmm0
    movdqu [rdi + 104], xmm0
    movq [rdi + 120], xmm0
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
