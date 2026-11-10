; Select the first valid resolv.conf nameserver or IPv4 loopback.
; RDI resolver context, RSI a 32-byte sockaddr buffer. Return its length.
bits 64
default rel

global __al_dns_server:function
extern __al_dns_config:function

section .text.__al_dns_server alloc exec nowrite progbits
__al_dns_server:
    sub rsp, 8
    xor edx, edx               ; reverse lookups do not use search configuration
    call __al_dns_config
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
