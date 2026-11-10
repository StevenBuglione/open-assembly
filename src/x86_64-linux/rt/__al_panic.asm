; Original implementation. Safe to call before FS and libc are initialized.
bits 64
default rel

global __al_panic:function
extern __al_diagnostic:function
extern _exit:function

section .text.__al_panic alloc exec nowrite progbits
__al_panic:
    push rbp
    mov rbp, rsp
    call __al_diagnostic
    mov edi, 127
    call _exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
