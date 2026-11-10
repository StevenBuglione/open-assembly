; Original floating format dispatcher. rdi = sink, rsi = fields,
; rdx = binary64 or extended significand, rcx = extended exponent/sign.
bits 64
default rel

global __al_fmt_float:function
extern __al_fmt_dec_body:function
extern __al_fmt_hex_body:function
extern __al_fmt_fp_output:function
extern memset:function

section .text.__al_fmt_float alloc exec nowrite progbits
__al_fmt_float:
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
    lea rdi, [rel description]
    xor esi, esi
    mov edx, 72
    call memset
    mov qword [rsp], 0           ; finite
    cmp qword [r12 + 24], 16
    je .extended

    mov r15, r13
    shr r15, 63
    mov r14, r13
    shr r14, 52
    and r14d, 2047
    shl r13, 12
    shr r13, 12
    cmp r14d, 2047
    je .double_special
    test r14d, r14d
    jz .double_subnormal
    mov rax, 0x0010000000000000
    or r13, rax
    sub r14, 1075
    jmp .sign
.double_subnormal:
    mov r14, -1074
    jmp .sign
.double_special:
    mov qword [rsp], 1
    test r13, r13
    jz .sign
    mov qword [rsp], 2
    jmp .sign

.extended:
    mov r15, r14
    shr r15, 15
    and r15d, 1
    and r14d, 32767
    cmp r14d, 32767
    je .extended_special
    test r14d, r14d
    jz .extended_subnormal
    sub r14, 16446
    jmp .sign
.extended_subnormal:
    mov r14, -16445
    jmp .sign
.extended_special:
    mov qword [rsp], 1
    mov rax, 0x8000000000000000
    cmp r13, rax
    je .sign
    mov qword [rsp], 2

.sign:
    test r15d, r15d
    jz .positive
    mov byte [rel description + 40], 45
    jmp .kind
.positive:
    test qword [r12], 2
    jnz .plus
    test qword [r12], 4
    jz .kind
    mov byte [rel description + 40], 32
    jmp .kind
.plus:
    mov byte [rel description + 40], 43
.kind:
    cmp qword [rsp], 0
    jne .special
    lea rdi, [rel description]
    mov rsi, r12
    mov rdx, r13
    mov rcx, r14
    mov r8, r15
    mov eax, [r12 + 32]
    or eax, 32
    cmp eax, 97
    je .hex
    call __al_fmt_dec_body
    jmp .output
.hex:
    call __al_fmt_hex_body
    jmp .output
.special:
    mov qword [rel description + 8], 3
    mov qword [rel description + 64], 1
    cmp qword [rsp], 2
    je .nan
    lea rax, [rel lower_inf]
    cmp byte [r12 + 32], 97
    jae .special_ready
    lea rax, [rel upper_inf]
    jmp .special_ready
.nan:
    lea rax, [rel lower_nan]
    cmp byte [r12 + 32], 97
    jae .special_ready
    lea rax, [rel upper_nan]
.special_ready:
    mov [rel description], rax
.output:
    mov rdi, rbx
    mov rsi, r12
    lea rdx, [rel description]
    call __al_fmt_fp_output
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_fmt_float alloc noexec nowrite progbits
lower_inf:
    db "inf"
upper_inf:
    db "INF"
lower_nan:
    db "nan"
upper_nan:
    db "NAN"

section .bss.__al_fmt_float alloc noexec write nobits align=8
description:
    resq 9

section .note.GNU-stack noalloc noexec nowrite progbits
