; Keep the app-private entry point linked to the HTTP package.
bits 64
default rel

global __al_http_parse:function
extern http_parse:function

section .text.__al_http_parse alloc exec nowrite progbits
__al_http_parse:
    sub rsp, 8
    call http_parse
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
