bits 64
default rel
section .text
global __wrap___al_http_parse:function
__wrap___al_http_parse:
    xor eax, eax
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
