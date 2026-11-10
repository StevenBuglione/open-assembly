; Accept a temporary x87 value popped before returning.
bits 64
default rel

section .text
global test_valid_x87_balance:function
test_valid_x87_balance:
    fld1
    fstp st0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
