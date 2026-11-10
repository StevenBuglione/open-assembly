; Wait for a descriptor against the work block's absolute deadline.
; The pollfd starts at offset 24. Return one when an event is available.
bits 64
default rel

global __al_dns_wait:function
extern __al_dns_now:function
extern __errno_location:function
extern poll:function

section .text.__al_dns_wait alloc exec nowrite progbits
__al_dns_wait:
    push r12
    push r13
    push r14
    movsxd r12, edi
    movzx r13d, si
    mov r14, rdx
    mov [r14 + 24], r12d
    mov [r14 + 28], r13w
.again:
    mov rdi, r14
    call __al_dns_now
    test rax, rax
    js .no_event
    mov rdx, [r14]
    sub rdx, rax
    jbe .no_event
    lea rdi, [r14 + 24]
    mov esi, 1
    call poll
    test eax, eax
    jns .return
    call __errno_location
    cmp dword [rax], 4          ; EINTR does not restart the deadline
    je .again
.no_event:
    xor eax, eax
.return:
    pop r14
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
