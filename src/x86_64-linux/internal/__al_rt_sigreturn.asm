; Original implementation. Linux enters here with a kernel signal frame.
bits 64
default rel

global __al_rt_sigreturn:function

section .text.__al_rt_sigreturn alloc exec nowrite progbits
__al_rt_sigreturn:
    mov eax, 15                    ; __NR_rt_sigreturn
    syscall
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
