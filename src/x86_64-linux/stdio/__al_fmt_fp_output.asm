; Original padded floating output. rdi = sink, rsi = format fields,
; rdx = head/zero-run/suffix/sign/radix-prefix description.
bits 64
default rel

global __al_fmt_fp_output:function
extern __al_fmt_emit:function
extern __al_stdio_errno:function

section .text.__al_fmt_fp_output alloc exec nowrite progbits
__al_fmt_fp_output:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor r14d, r14d                ; width padding
    xor r15d, r15d                ; width padding uses zero
    mov rax, [r13 + 8]
    add rax, [r13 + 16]
    add rax, [r13 + 32]
    add rax, [r13 + 56]
    cmp byte [r13 + 40], 0
    je .width
    inc rax
.width:
    mov rcx, [r12 + 8]
    cmp rcx, rax
    jbe .bound
    mov r14, rcx
    sub r14, rax
    mov rax, rcx
.bound:
    add rax, [rbx + 16]
    cmp rax, 2147483647
    ja .overflow
    test qword [r12], 1
    jnz .sign
    test qword [r12], 16
    jz .leading_space
    cmp qword [r13 + 64], 0      ; INF and NAN are space-padded
    jne .leading_space
    mov r15d, 1
    jmp .sign
.leading_space:
    mov rdi, rbx
    xor esi, esi
    mov rdx, r14
    mov ecx, 32
    call __al_fmt_emit
    test eax, eax
    jnz .done
.sign:
    cmp byte [r13 + 40], 0
    je .prefix
    mov rdi, rbx
    lea rsi, [r13 + 40]
    mov edx, 1
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jnz .done
.prefix:
    mov rdi, rbx
    mov rsi, [r13 + 48]
    mov rdx, [r13 + 56]
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jnz .done
    test r15d, r15d
    jz .body
    mov rdi, rbx
    xor esi, esi
    mov rdx, r14
    mov ecx, 48
    call __al_fmt_emit
    test eax, eax
    jnz .done
.body:
    mov rdi, rbx
    mov rsi, [r13]
    mov rdx, [r13 + 8]
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jnz .done
    mov rdi, rbx
    xor esi, esi
    mov rdx, [r13 + 16]
    mov ecx, 48
    call __al_fmt_emit
    test eax, eax
    jnz .done
    mov rdi, rbx
    mov rsi, [r13 + 24]
    mov rdx, [r13 + 32]
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jnz .done
    test qword [r12], 1
    jz .done
    mov rdi, rbx
    xor esi, esi
    mov rdx, r14
    mov ecx, 32
    call __al_fmt_emit
    jmp .done
.overflow:
    mov edi, 75
    call __al_stdio_errno
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
