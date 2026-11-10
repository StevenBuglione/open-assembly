; Restore R15 and then corrupt its low byte.
bits 64
default rel

section .text
global seed_clobber_r15_after_restore:function
seed_clobber_r15_after_restore:
    push r15
    pop r15
    mov r15b, 0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
