; Original local conversion under the zone lock. Inputs: zone, epoch
; seconds, result. Return result or null with EOVERFLOW.
bits 64
default rel

global __al_zone_publish:function
extern __al_zone_lookup:function
extern __al_utc_convert:function
extern __al_syscall_result:function

section .text.__al_zone_publish alloc exec nowrite progbits
__al_zone_publish:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov rax, 70000000000000000
    cmp rsi, rax
    jg .overflow
    neg rax
    cmp rsi, rax
    jl .overflow
    mov rbx, rsi
    mov r12, rdx
    call __al_zone_lookup
    add rbx, rax
    jo .overflow
    mov r13, rax
    mov r14, rdx
    mov [rsp], rcx                ; DST value survives Gregorian conversion
    mov rdi, rbx
    mov rsi, r12
    call __al_utc_convert
    test rax, rax
    jz .done
    mov rcx, [rsp]
    mov [r12 + 32], ecx
    mov [r12 + 40], r13
    mov [r12 + 48], r14
    jmp .done
.overflow:
    mov rdi, -75
    call __al_syscall_result
    xor eax, eax
.done:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
