; Leave a value on the x87 stack at an integer return.
bits 64
default rel

section .text
global seed_x87_at_return:function
seed_x87_at_return:
    fld1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
