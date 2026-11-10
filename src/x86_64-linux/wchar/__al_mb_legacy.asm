; Decode a legacy character with no incomplete result, using state slot ecx.
bits 64
default rel

global __al_mb_legacy:function
extern __al_mbstate_default:function
extern __al_mb_decode:function
extern __al_mb_error:function

section .text.__al_mb_legacy alloc exec nowrite progbits
__al_mb_legacy:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov edi, ecx
    call __al_mbstate_default
    mov r14, rax
    mov qword [r14], 0
    xor eax, eax
    test r12, r12
    jz .done
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call __al_mb_decode
    cmp rax, -2
    je .incomplete
    test rax, rax
    js .done
    test rbx, rbx
    jz .done
    mov [rbx], edx
    jmp .done
.incomplete:
    mov rdi, r14
    call __al_mb_error
.done:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
