; Hide an instruction byte in an executable section.
bits 64
default rel

section .text
global seed_data_in_text:function
seed_data_in_text:
    db 0x90
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
