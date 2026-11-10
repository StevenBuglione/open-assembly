; Accept local changes to DF if DF is clear at calls and return.
bits 64
default rel

section .text
global test_valid_direction_flag:function
extern external_target
test_valid_direction_flag:
    std
    cld
    sub rsp, 8
    call external_target
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
