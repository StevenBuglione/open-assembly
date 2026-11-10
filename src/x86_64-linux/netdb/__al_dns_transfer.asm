; Transfer an exact byte count with an absolute deadline. Direction one
; sends, zero receives. Return one for a complete transfer.
bits 64
default rel

global __al_dns_transfer:function
extern __al_dns_wait:function
extern __errno_location:function
extern recv:function
extern send:function

section .text.__al_dns_transfer alloc exec nowrite progbits
__al_dns_transfer:
    push rbx
    push r12
    push r13
    push r14
    push r15
    movsxd rbx, edi             ; descriptor
    mov r12, rsi                ; next byte
    mov r13, rdx                ; remaining bytes
    mov r14d, ecx               ; direction
    mov r15, r8                 ; work block
.next:
    test r13, r13
    jz .complete
    mov edi, ebx
    mov esi, 1                  ; POLLIN
    test r14d, r14d
    jz .wait
    mov esi, 4                  ; POLLOUT
.wait:
    mov rdx, r15
    call __al_dns_wait
    test eax, eax
    jz .failed
    mov edi, ebx
    mov rsi, r12
    mov rdx, r13
    xor ecx, ecx
    test r14d, r14d
    jnz .send
    call recv
    jmp .result
.send:
    mov ecx, 16384              ; MSG_NOSIGNAL
    call send
.result:
    test rax, rax
    js .error
    jz .failed
    add r12, rax
    sub r13, rax
    jmp .next
.error:
    call __errno_location
    mov eax, [rax]
    cmp eax, 4                  ; EINTR
    je .next
    cmp eax, 11                 ; EAGAIN
    je .next
.failed:
    xor eax, eax
    jmp .return
.complete:
    mov eax, 1
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
