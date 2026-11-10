; Original ASCII floating lexer. rdi = input, rsi = significand bigint,
; rdx = metadata: end, sign, exponent, radix, sticky, retained digits.
; rcx = input stride, one or four bytes.
; Returns -1 absent, 0 zero, 1 finite nonzero, 2 infinity, 3 quiet NaN.
bits 64
default rel

global __al_float_lex:function
extern __al_float_keyword:function
extern __al_big_muladd:function

section .text.__al_float_lex alloc exec nowrite progbits
__al_float_lex:
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
    mov [r13], rdi
    mov qword [r13 + 8], 0
    mov qword [r13 + 32], 0
    mov qword [r12], 0
    mov qword [rsp], 0            ; digits before the period
    mov qword [rsp + 8], 0        ; leading zero digits
    mov qword [rsp + 16], 0       ; period consumed
    mov qword [rsp + 24], 0       ; any digit consumed
    mov qword [rsp + 32], 0       ; explicit exponent negative
    mov [rsp + 40], rcx          ; input stride
    mov r14d, 10
    xor r15d, r15d                ; retained significant digits

.space:
    cmp qword [rsp + 40], 4
    je .wide_space
    movzx eax, byte [rbx]
    jmp .space_loaded
.wide_space:
    mov eax, [rbx]
.space_loaded:
    cmp eax, 32
    je .skip_space
    lea rcx, [rax - 9]
    cmp rcx, 4
    ja .sign
.skip_space:
    add rbx, [rsp + 40]
    jmp .space
.sign:
    cmp eax, 45
    jne .plus
    mov qword [r13 + 8], 1
    add rbx, [rsp + 40]
    jmp .keyword
.plus:
    cmp eax, 43
    jne .keyword
    add rbx, [rsp + 40]
.keyword:
    cmp qword [rsp + 40], 4
    je .wide_keyword
    movzx eax, byte [rbx]
    jmp .keyword_loaded
.wide_keyword:
    mov eax, [rbx]
.keyword_loaded:
    or eax, 32
    cmp eax, 105                  ; i
    je .infinity
    cmp eax, 110                  ; n
    je .nan
    jmp .prefix
.infinity:
    mov rdi, rbx
    lea rsi, [rel inf_word]
    mov edx, [rsp + 40]
    call __al_float_keyword
    test rax, rax
    jz .absent
    mov rbx, rax
    mov rdi, rax
    lea rsi, [rel infinity_tail]
    mov edx, [rsp + 40]
    call __al_float_keyword
    test rax, rax
    jz .finish_inf
    mov rbx, rax
.finish_inf:
    mov [r13], rbx
    mov eax, 2
    jmp .done
.nan:
    mov rdi, rbx
    lea rsi, [rel nan_word]
    mov edx, [rsp + 40]
    call __al_float_keyword
    test rax, rax
    jz .absent
    mov rbx, rax
    cmp qword [rsp + 40], 4
    je .wide_payload_open
    movzx eax, byte [rbx]
    jmp .payload_open_loaded
.wide_payload_open:
    mov eax, [rbx]
.payload_open_loaded:
    cmp eax, 40                  ; (
    jne .finish_nan
    mov rdx, rbx
    add rdx, [rsp + 40]
.payload:
    cmp qword [rsp + 40], 4
    je .wide_payload
    movzx ecx, byte [rdx]
    jmp .payload_loaded
.wide_payload:
    mov ecx, [rdx]
.payload_loaded:
    cmp ecx, 41                  ; )
    je .consume_payload
    cmp ecx, 95                  ; _
    je .next_payload
    lea r8, [rcx - 48]
    cmp r8, 9
    jbe .next_payload
    or ecx, 32
    lea r8, [rcx - 97]
    cmp r8, 25
    ja .finish_nan
.next_payload:
    add rdx, [rsp + 40]
    jmp .payload
.consume_payload:
    mov rbx, rdx
    add rbx, [rsp + 40]
.finish_nan:
    mov [r13], rbx
    mov eax, 3
    jmp .done

.prefix:
    cmp qword [rsp + 40], 4
    je .wide_prefix_zero
    movzx eax, byte [rbx]
    jmp .prefix_zero_loaded
.wide_prefix_zero:
    mov eax, [rbx]
.prefix_zero_loaded:
    cmp eax, 48
    jne .digits
    mov r10, [rsp + 40]
    cmp qword [rsp + 40], 4
    je .wide_prefix_letter
    movzx eax, byte [rbx + r10]
    jmp .prefix_letter_loaded
.wide_prefix_letter:
    mov eax, [rbx + r10]
.prefix_letter_loaded:
    or eax, 32
    cmp eax, 120                 ; x
    jne .digits
    lea rdx, [rbx + r10 * 2]
    cmp qword [rsp + 40], 4
    je .wide_prefix_period
    movzx eax, byte [rdx]
    jmp .prefix_period_loaded
.wide_prefix_period:
    mov eax, [rdx]
.prefix_period_loaded:
    cmp eax, 46
    jne .hex_first
    add rdx, r10
.hex_first:
    cmp qword [rsp + 40], 4
    je .wide_prefix_digit
    movzx eax, byte [rdx]
    jmp .prefix_digit_loaded
.wide_prefix_digit:
    mov eax, [rdx]
.prefix_digit_loaded:
    lea rcx, [rax - 48]
    cmp rcx, 9
    jbe .commit_hex
    or eax, 32
    lea rcx, [rax - 97]
    cmp rcx, 5
    ja .digits
.commit_hex:
    lea rbx, [rbx + r10 * 2]
    mov r14d, 16

.digits:
    cmp qword [rsp + 40], 4
    je .wide_digit
    movzx eax, byte [rbx]
    jmp .digit_loaded
.wide_digit:
    mov eax, [rbx]
.digit_loaded:
    lea rdx, [rax - 48]
    cmp rdx, 9
    jbe .valid_digit
    cmp eax, 46
    je .period
    cmp r14, 16
    jne .after_digits
    or eax, 32
    lea rdx, [rax - 87]
    cmp rdx, 10
    jb .after_digits
    cmp rdx, 15
    ja .after_digits
.valid_digit:
    mov qword [rsp + 24], 1
    cmp qword [rsp + 16], 0
    jne .leading
    inc qword [rsp]
.leading:
    test r15, r15
    jnz .significant
    test rdx, rdx
    jnz .significant
    inc qword [rsp + 8]
    jmp .next_digit
.significant:
    mov ecx, 22000
    cmp r14, 10
    je .limit
    mov ecx, 24
.limit:
    cmp r15, rcx
    jae .discarded
    mov rdi, r12
    mov rsi, r14
    call __al_big_muladd
    inc r15
    jmp .next_digit
.discarded:
    test rdx, rdx
    jz .next_digit
    mov qword [r13 + 32], 1
.next_digit:
    add rbx, [rsp + 40]
    jmp .digits
.period:
    cmp qword [rsp + 16], 0
    jne .after_digits
    mov qword [rsp + 16], 1
    add rbx, [rsp + 40]
    jmp .digits

.after_digits:
    cmp qword [rsp + 24], 0
    je .absent
    cmp qword [rsp + 40], 4
    je .wide_marker
    movzx eax, byte [rbx]
    jmp .marker_loaded
.wide_marker:
    mov eax, [rbx]
.marker_loaded:
    or eax, 32
    mov ecx, 101                  ; decimal exponent e
    cmp r14, 10
    je .marker
    mov ecx, 112                  ; hexadecimal exponent p
.marker:
    cmp eax, ecx
    jne .no_exponent
    mov rdi, rbx
    add rdi, [rsp + 40]
    cmp qword [rsp + 40], 4
    je .wide_exponent_sign
    movzx ecx, byte [rdi]
    jmp .exponent_sign_loaded
.wide_exponent_sign:
    mov ecx, [rdi]
.exponent_sign_loaded:
    cmp ecx, 45
    jne .exponent_plus
    mov qword [rsp + 32], 1
    add rdi, [rsp + 40]
    jmp .first_exponent
.exponent_plus:
    cmp ecx, 43
    jne .first_exponent
    add rdi, [rsp + 40]
.first_exponent:
    cmp qword [rsp + 40], 4
    je .wide_first_exponent
    movzx ecx, byte [rdi]
    jmp .first_exponent_loaded
.wide_first_exponent:
    mov ecx, [rdi]
.first_exponent_loaded:
    sub ecx, 48
    cmp ecx, 9
    ja .no_exponent
    xor eax, eax
    mov r8, 0x1000000000000000   ; exceeds the size of any valid user string
.exponent_digit:
    cmp rax, r8
    jae .advance_exponent
    lea rax, [rax + rax*4]
    lea rax, [rcx + rax*2]
    cmp rax, r8
    jbe .advance_exponent
    mov rax, r8
.advance_exponent:
    add rdi, [rsp + 40]
    cmp qword [rsp + 40], 4
    je .wide_next_exponent
    movzx ecx, byte [rdi]
    jmp .next_exponent_loaded
.wide_next_exponent:
    mov ecx, [rdi]
.next_exponent_loaded:
    sub ecx, 48
    cmp ecx, 9
    jbe .exponent_digit
    mov rbx, rdi
    cmp qword [rsp + 32], 0
    je .adjust
    neg rax
    jmp .adjust
.no_exponent:
    xor eax, eax
.adjust:
    mov rdx, [rsp]
    sub rdx, [rsp + 8]
    sub rdx, r15
    cmp r14, 10
    je .add_exponent
    shl rdx, 2                    ; one hex digit represents four binary bits
.add_exponent:
    add rdx, rax
    mov [r13], rbx
    mov [r13 + 16], rdx
    mov [r13 + 24], r14
    mov [r13 + 40], r15
    xor eax, eax
    test r15, r15
    jz .done
    mov eax, 1
    jmp .done
.absent:
    mov rax, -1
.done:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_float_lex alloc noexec nowrite progbits
inf_word:
    db "inf", 0
infinity_tail:
    db "inity", 0
nan_word:
    db "nan", 0

section .note.GNU-stack noalloc noexec nowrite progbits
