; Query one Linux ifreq using a private close-on-exec datagram socket.
; RDI writable 40-byte ifreq, RSI ioctl request. Return zero or -errno.
bits 64
default rel

global __al_netdb_ifreq:function
extern __errno_location:function
extern close:function
extern ioctl:function
extern socket:function

section .text.__al_netdb_ifreq alloc exec nowrite progbits
__al_netdb_ifreq:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov edi, 2                 ; AF_INET
    mov esi, 524290            ; SOCK_DGRAM | SOCK_CLOEXEC
    xor edx, edx
    call socket
    test eax, eax
    js .socket_error
    mov r13d, eax
    mov edi, eax
    mov rsi, r12
    mov rdx, rbx
    xor eax, eax
    call ioctl
    xor r12d, r12d
    test eax, eax
    jns .close
    call __errno_location
    mov r12d, [rax]
    neg r12d
.close:
    mov edi, r13d
    call close
    mov eax, r12d
    jmp .return
.socket_error:
    call __errno_location
    mov eax, [rax]
    neg eax
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
