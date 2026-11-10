; Resolve one DNS question with the default two-second per-phase deadline.
bits 64
default rel

global __al_dns_query:function
extern __al_dns_query_timeout:function

section .text.__al_dns_query alloc exec nowrite progbits
__al_dns_query:
    sub rsp, 8
    mov r9d, 2000
    call __al_dns_query_timeout
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
