; Clear the SysV vector-argument count for the integer-only variadic call.
bits 64
default rel
global fcntl_integer_thunk:function
extern fcntl:function

section .text
fcntl_integer_thunk:
    xor eax, eax
    jmp fcntl

section .note.GNU-stack noalloc noexec nowrite progbits
