; The shared register probe takes integer arguments. Set the System V
; variadic vector-register count before transferring to open/openat.
bits 64
default rel

global probe_open:function
global probe_openat:function
extern open:function
extern openat:function

section .text
probe_open:
    xor eax, eax
    jmp open

probe_openat:
    xor eax, eax
    jmp openat

section .note.GNU-stack noalloc noexec nowrite progbits
