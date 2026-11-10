; Carry an x87 stack value into a call that requires an empty stack.
bits 64
default rel

section .text
global seed_x87_at_call:function
extern external_target
seed_x87_at_call:
    sub rsp, 8
    fld1
    call external_target
    fstp st0
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
