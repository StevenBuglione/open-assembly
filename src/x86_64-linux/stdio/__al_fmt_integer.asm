; Original integer renderer. rdi = sink, rsi = fields, rdx = argument bits.
; The stdio lock protects the digit and prefix scratch storage.
bits 64
default rel

global __al_fmt_integer:function
extern __al_fmt_emit:function
extern __al_stdio_errno:function

section .text.__al_fmt_integer alloc exec nowrite progbits
__al_fmt_integer:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov qword [rsp], 0            ; sign or radix prefix
    mov qword [rsp + 8], 0        ; digit count
    mov qword [rsp + 16], 0       ; leading zeros
    mov qword [rsp + 24], 0       ; spaces
    mov eax, [r12 + 32]
    cmp eax, 100                  ; d
    je .signed
    cmp eax, 105                  ; i
    je .signed
    cmp eax, 112                  ; p
    je .select_base
    mov rcx, [r12 + 24]
    cmp rcx, 8
    je .select_base
    cmp rcx, 4
    je .unsigned_int
    cmp rcx, 2
    je .unsigned_short
    and r13d, 255
    jmp .select_base
.unsigned_short:
    and r13d, 65535
    jmp .select_base
.unsigned_int:
    mov r13d, r13d
    jmp .select_base

.signed:
    mov rcx, [r12 + 24]
    cmp rcx, 8
    je .sign
    cmp rcx, 4
    je .signed_int
    cmp rcx, 2
    je .signed_short
    movsx r13, r13b
    jmp .sign
.signed_short:
    movsx r13, r13w
    jmp .sign
.signed_int:
    movsxd r13, r13d
.sign:
    test r13, r13
    js .negative
    test qword [r12], 2
    jnz .plus
    test qword [r12], 4
    jz .select_base
    mov byte [rel prefix], 32
    jmp .one_prefix
.plus:
    mov byte [rel prefix], 43
    jmp .one_prefix
.negative:
    mov byte [rel prefix], 45
    neg r13                      ; unsigned magnitude, including INT64_MIN
.one_prefix:
    mov qword [rsp], 1

.select_base:
    mov [rsp + 32], r13           ; original magnitude
    mov r14d, 10
    lea r8, [rel lower_digits]
    mov eax, [r12 + 32]
    cmp eax, 111                  ; o
    je .octal
    cmp eax, 88                   ; X
    je .hex_upper
    cmp eax, 120                  ; x
    je .hex_lower
    cmp eax, 112                  ; p
    jne .convert
    mov r14d, 16
    jmp .prefix_lower
.octal:
    mov r14d, 8
    jmp .convert
.hex_upper:
    mov r14d, 16
    lea r8, [rel upper_digits]
    test qword [r12], 8
    jz .convert
    test r13, r13
    jz .convert
    mov word [rel prefix], 0x5830
    jmp .two_prefix
.hex_lower:
    mov r14d, 16
    test qword [r12], 8
    jz .convert
    test r13, r13
    jz .convert
.prefix_lower:
    mov word [rel prefix], 0x7830
.two_prefix:
    mov qword [rsp], 2

.convert:
    lea r15, [rel digit_space + 32]
    test r13, r13
    jnz .prepare
    cmp qword [r12 + 16], 0
    jne .prepare
    cmp dword [r12 + 32], 112
    jne .precision
.prepare:
    mov rax, r13
.digit:
    xor edx, edx
    div r14
    mov cl, [r8 + rdx]
    dec r15
    mov [r15], cl
    inc qword [rsp + 8]
    test rax, rax
    jnz .digit
.precision:
    mov rax, [r12 + 16]
    cmp rax, [rsp + 8]
    jle .octal_prefix
    sub rax, [rsp + 8]
    mov [rsp + 16], rax
.octal_prefix:
    cmp r14, 8
    jne .width
    test qword [r12], 8
    jz .width
    cmp qword [rsp + 16], 0
    jne .width
    cmp qword [rsp + 8], 0
    je .force_zero
    cmp qword [rsp + 32], 0
    je .width
.force_zero:
    mov qword [rsp + 16], 1

.width:
    mov rcx, [rsp]
    add rcx, [rsp + 8]
    add rcx, [rsp + 16]
    mov rax, [r12 + 8]
    cmp rax, rcx
    jbe .check_count
    mov rdx, rax
    sub rdx, rcx
    mov rcx, rax
    test qword [r12], 1
    jnz .space_padding
    test qword [r12], 16
    jz .space_padding
    cmp qword [r12 + 16], 0
    jge .space_padding
    add [rsp + 16], rdx
    jmp .check_count
.space_padding:
    mov [rsp + 24], rdx
.check_count:
    add rcx, [rbx + 16]
    cmp rcx, 2147483647
    ja .overflow
    test qword [r12], 1
    jnz .emit_prefix
    mov rdi, rbx
    xor esi, esi
    mov rdx, [rsp + 24]
    mov ecx, 32
    call __al_fmt_emit
    test eax, eax
    jnz .done
.emit_prefix:
    mov rdi, rbx
    lea rsi, [rel prefix]
    mov rdx, [rsp]
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jnz .done
    mov rdi, rbx
    xor esi, esi
    mov rdx, [rsp + 16]
    mov ecx, 48
    call __al_fmt_emit
    test eax, eax
    jnz .done
    mov rdi, rbx
    mov rsi, r15
    mov rdx, [rsp + 8]
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jnz .done
    test qword [r12], 1
    jz .done
    mov rdi, rbx
    xor esi, esi
    mov rdx, [rsp + 24]
    mov ecx, 32
    call __al_fmt_emit
    jmp .done
.overflow:
    mov edi, 75
    call __al_stdio_errno
.done:
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_fmt_integer alloc noexec nowrite progbits
lower_digits:
    db "0123456789abcdef"
upper_digits:
    db "0123456789ABCDEF"

section .bss.__al_fmt_integer alloc noexec write nobits align=8
prefix:
    resb 2
digit_space:
    resb 32

section .note.GNU-stack noalloc noexec nowrite progbits
