; Load an x87 control word without restoring caller state.
bits 64
default rel

section .text
global seed_x87_control_changed:function
seed_x87_control_changed:
    fldcw [rdi]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
