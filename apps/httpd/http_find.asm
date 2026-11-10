; Keep the app-private entry point linked to the HTTP package.
bits 64
default rel

global __al_http_find:function
extern http_find_header_end:function

section .text.__al_http_find alloc exec nowrite progbits
__al_http_find:
    sub rsp, 8
    call http_find_header_end
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
