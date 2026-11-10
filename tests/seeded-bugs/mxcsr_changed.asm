; Load MXCSR from an argument without restoring caller control bits.
bits 64
default rel

section .text
global seed_mxcsr_changed:function
seed_mxcsr_changed:
    ldmxcsr [rdi]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
