; Original padded character/string emitter. rdi = context, rsi = fields,
; rdx = bytes, rcx = byte count. Returns 0 or -1.
bits 64
default rel

global __al_fmt_text:function
extern __al_fmt_emit:function

section .text.__al_fmt_text alloc exec nowrite progbits
__al_fmt_text:
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
    mov r14, rcx
    xor r15d, r15d
    mov rax, [r12 + 8]           ; requested field width
    cmp rax, r14
    jbe .bytes
    sub rax, r14
    mov r15, rax
    test qword [r12], 1          ; left adjustment
    jnz .bytes
    mov rdi, rbx
    xor esi, esi
    mov rdx, r15
    mov ecx, 32
    call __al_fmt_emit
    test eax, eax
    jnz .done
.bytes:
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r14
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jnz .done
    test qword [r12], 1
    jz .done
    mov rdi, rbx
    xor esi, esi
    mov rdx, r15
    mov ecx, 32
    call __al_fmt_emit
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
