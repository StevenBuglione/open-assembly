; Emit a wide scalar or string as bytes. RDI is the sink, RSI the fields,
; and RDX the argument. Return zero or minus one.
bits 64
default rel

global __al_fmt_nwide:function
extern __al_locale_flags:data
extern __al_mb_encode:function
extern __al_fmt_text:function
extern __al_fmt_emit:function
extern __al_stdio_errno:function

section .text.__al_fmt_nwide alloc exec nowrite progbits
__al_fmt_nwide:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov qword [rbx + 56], 0          ; initial multibyte state
    mov eax, [rel __al_locale_flags]
    and eax, 1
    inc eax
    mov [rsp], eax         ; use one encoding for the entire conversion
    cmp qword [r12 + 32], 99
    jne .string
    lea rdi, [rbx + 32]
    mov esi, r13d
    lea rdx, [rbx + 56]
    mov ecx, eax
    call __al_mb_encode
    test rax, rax
    js .return
    mov rdi, rbx
    mov rsi, r12
    lea rdx, [rbx + 32]
    mov rcx, rax
    call __al_fmt_text
    jmp .return
.string:
    test r13, r13
    jnz .measure
    lea r13, [rel null_wide]
.measure:
    mov [rsp + 8], r13
    xor r14d, r14d
.measure_next:
    cmp r14, [r12 + 16]
    jae .padding
    mov rax, [rsp + 8]
    mov esi, [rax]
    test esi, esi
    jz .padding
    xor edi, edi
    lea rdx, [rbx + 56]
    mov ecx, [rsp]
    call __al_mb_encode
    test rax, rax
    js .return
    add rax, r14
    cmp rax, [r12 + 16]
    ja .padding
    cmp rax, 2147483647
    ja .overflow
    mov r14, rax
    add qword [rsp + 8], 4
    jmp .measure_next
.padding:
    xor r15d, r15d
    mov rax, [r12 + 8]
    cmp rax, r14
    jbe .body
    sub rax, r14
    mov r15, rax
    test qword [r12], 1
    jnz .body
    mov rdi, rbx
    xor esi, esi
    mov rdx, r15
    mov ecx, 32
    call __al_fmt_emit
    test eax, eax
    jnz .return
.body:
    test r14, r14
    jz .trailing
    lea rdi, [rbx + 32]
    mov esi, [r13]
    lea rdx, [rbx + 56]
    mov ecx, [rsp]
    call __al_mb_encode
    test rax, rax
    js .return
    sub r14, rax
    add r13, 4
    mov rdi, rbx
    lea rsi, [rbx + 32]
    mov rdx, rax
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jz .body
    jmp .return
.trailing:
    xor eax, eax
    test qword [r12], 1
    jz .return
    mov rdi, rbx
    xor esi, esi
    mov rdx, r15
    mov ecx, 32
    call __al_fmt_emit
    jmp .return
.overflow:
    mov edi, 75                ; EOVERFLOW
    call __al_stdio_errno
    mov eax, -1
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_fmt_nwide alloc noexec nowrite progbits align=4
null_wide: dd 40, 110, 117, 108, 108, 41, 0

section .note.GNU-stack noalloc noexec nowrite progbits
