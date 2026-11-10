; Return with the direction flag set.
bits 64
default rel

section .text
global seed_df_at_return:function
seed_df_at_return:
    std
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
