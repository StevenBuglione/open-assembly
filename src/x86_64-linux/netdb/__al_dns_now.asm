; Read monotonic milliseconds, using the work block's timespec at offset 8.
bits 64
default rel

global __al_dns_now:function
extern clock_gettime:function

section .text.__al_dns_now alloc exec nowrite progbits
__al_dns_now:
    push rbx
    mov rbx, rdi
    mov edi, 1                  ; CLOCK_MONOTONIC
    lea rsi, [rbx + 8]
    call clock_gettime
    test eax, eax
    jnz .failed
    mov rax, [rbx + 16]
    xor edx, edx
    mov ecx, 1000000
    div rcx
    mov rcx, [rbx + 8]
    imul rcx, 1000
    add rax, rcx
    jmp .return
.failed:
    mov rax, -1
.return:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
