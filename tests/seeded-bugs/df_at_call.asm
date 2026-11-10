; Call with DF set, then clear it before the return.
bits 64
default rel

section .text
global seed_df_at_call:function
extern external_target
seed_df_at_call:
    sub rsp, 8
    std
    call external_target
    cld
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
