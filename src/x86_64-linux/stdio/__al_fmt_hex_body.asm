; Original hexadecimal printf layout. rdi = output description,
; rsi = fields, rdx = significand, rcx = binary exponent, r8 = sign.
bits 64
default rel

global __al_fmt_hex_body:function
extern fegetround:function
extern __al_fmt_exponent:function

section .text.__al_fmt_hex_body alloc exec nowrite progbits
__al_fmt_hex_body:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov [rsp], r8                 ; negative flag
    xor r15d, r15d               ; leading hex digit
    test r13, r13
    jz .zero

    mov rax, r13
    xor ecx, ecx
.top_bit:
    shr rax, 1
    jz .normalize
    inc ecx
    jmp .top_bit
.normalize:
    add r14, rcx
    mov edx, 63
    sub edx, ecx
    mov ecx, edx
    shl r13, cl
    shl r13, 1                   ; retain the fraction aligned to bit 63
    mov r15d, 1
    jmp .precision
.zero:
    xor r14d, r14d
.precision:
    mov rax, [r12 + 16]
    test rax, rax
    jns .specified
    mov eax, 16
    mov rdx, r13
.trim:
    test eax, eax
    jz .specified
    test rdx, 15
    jnz .specified
    shr rdx, 4
    dec eax
    jmp .trim
.specified:
    mov [rsp + 8], rax            ; requested fraction digits
    cmp qword [r12 + 16], 0
    jl .layout                   ; an omitted precision is exact
    cmp rax, 16
    jae .layout

    lea rcx, [rax*4]              ; retained fraction bit count
    mov [rsp + 16], rcx
    mov rdx, 64
    sub rdx, rcx
    mov [rsp + 24], rdx           ; discarded bit count
    mov rax, -1
    shr rax, cl                  ; discarded-bit mask, including 64 when p=0
    and rax, r13
    mov [rsp + 32], rax
    test rcx, rcx
    jz .no_fraction
    mov rcx, rdx
    shr r13, cl
    jmp .check_remainder
.no_fraction:
    xor r13d, r13d
.check_remainder:
    test rax, rax
    jz .align
    call fegetround
    test eax, eax
    jz .nearest
    cmp eax, 1024
    je .downward
    cmp eax, 2048
    jne .align
    cmp qword [rsp], 0
    je .increment
    jmp .align
.downward:
    cmp qword [rsp], 0
    jne .increment
    jmp .align
.nearest:
    mov rcx, [rsp + 24]
    dec rcx
    mov eax, 1
    shl rax, cl
    cmp [rsp + 32], rax
    ja .increment
    jb .align
    cmp qword [rsp + 16], 0
    jne .fraction_tie
    test r15, 1
    jnz .increment
    jmp .align
.fraction_tie:
    test r13, 1
    jz .align
.increment:
    mov rcx, [rsp + 16]
    test rcx, rcx
    jz .leading_carry
    inc r13
    mov eax, 1
    shl rax, cl
    cmp r13, rax
    jb .align
    xor r13d, r13d
.leading_carry:
    inc r15
.align:
    cmp qword [rsp + 16], 0
    je .layout
    mov rcx, [rsp + 24]
    shl r13, cl

.layout:
    lea rax, [rel lower_prefix]
    lea r8, [rel lower_digits]
    mov edx, 112                  ; p
    cmp byte [r12 + 32], 97
    jae .case
    lea rax, [rel upper_prefix]
    lea r8, [rel upper_digits]
    mov edx, 80                   ; P
.case:
    mov [rbx + 48], rax
    mov qword [rbx + 56], 2
    mov [rsp + 40], edx
    lea rdi, [rel body]
    mov [rbx], rdi
    lea eax, [r15 + 48]
    mov [rdi], al
    mov ecx, 1
    mov rdx, [rsp + 8]
    test rdx, rdx
    jnz .point
    test qword [r12], 8
    jz .finish_body
.point:
    mov byte [rdi + rcx], 46
    inc rcx
    test rdx, rdx
    jz .finish_body
    mov r10, rdx
    cmp r10, 16
    jbe .digits
    mov r10d, 16
.digits:
    sub rdx, r10
    mov [rbx + 16], rdx
.next_digit:
    mov rax, r13
    shr rax, 60
    mov al, [r8 + rax]
    mov [rdi + rcx], al
    inc rcx
    shl r13, 4
    dec r10
    jnz .next_digit
.finish_body:
    mov [rbx + 8], rcx
    lea rdi, [rel exponent]
    mov [rbx + 24], rdi
    mov rsi, r14
    mov edx, [rsp + 40]
    mov ecx, 1
    call __al_fmt_exponent
    mov [rbx + 32], rax
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_fmt_hex_body alloc noexec nowrite progbits
lower_digits:
    db "0123456789abcdef"
upper_digits:
    db "0123456789ABCDEF"
lower_prefix:
    db "0x"
upper_prefix:
    db "0X"

section .bss.__al_fmt_hex_body alloc noexec write nobits align=8
body:
    resb 18
exponent:
    resb 8

section .note.GNU-stack noalloc noexec nowrite progbits
