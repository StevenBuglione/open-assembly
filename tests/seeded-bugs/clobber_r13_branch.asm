; Modify R13 only on the nonzero input path.
bits 64
default rel

section .text
global seed_clobber_r13_branch:function
seed_clobber_r13_branch:
    test rdi, rdi
    jz .done
    mov r13, rdi
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
