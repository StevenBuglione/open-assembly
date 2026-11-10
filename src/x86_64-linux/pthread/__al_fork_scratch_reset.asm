; Clear the explicitly owned transient guards in the single-threaded child.
bits 64
default rel

global __al_fork_scratch_reset:function
global __al_fork_scratch_locks:data

section .text.__al_fork_scratch_reset alloc exec nowrite progbits
__al_fork_scratch_reset:
    lea rax, [rel __al_fork_scratch_locks]
    xor ecx, ecx
.clear:
    mov dword [rax + rcx * 4], 0
    inc ecx
    cmp ecx, 30
    jb .clear
    ret

section .bss.__al_fork_scratch_reset alloc noexec write nobits align=8
__al_fork_scratch_locks:
    resd 3                    ; system, vformat, vscan
    resd 13                   ; asin, atan, erf, exp, fma, gamma, hyperbolic,
                              ; inverse hyperbolic, log, pow, root, trig, strtof
    resd 14                   ; complex distance, exp, geometric root, inverse
                              ; circle/tangent, log, power/arg/log, product,
                              ; sqrt, square comparison, tangent, odd series

section .note.GNU-stack noalloc noexec nowrite progbits
