; Original integer scanner for LP64 ASCII numeric subjects.
; rdi = input, rsi = endptr, rdx = base, rcx = flags.
; Flag bit 0 selects unsigned range, bit 1 suppresses errno for ato*,
; and bit 2 selects four-byte input.
bits 64
default rel

global __al_strtox:function
extern __errno_location:function

section .text.__al_strtox alloc exec nowrite progbits
__al_strtox:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    mov [rsp], rdi                ; original input
    mov [rsp + 8], rsi            ; endptr
    mov [rsp + 16], rcx           ; flags
    mov qword [rsp + 24], 0       ; negative sign
    mov r9, rdx                  ; base
    mov esi, 1                   ; input stride, endptr is saved
    test ecx, 4
    jz .check_base
    mov esi, 4
.check_base:
    test r9, r9
    jz .space
    cmp r9, 2
    jb .zero_result
    cmp r9, 36
    ja .zero_result
.space:
    cmp esi, 4
    je .wide_space
    movzx eax, byte [rdi]
    jmp .space_byte
.wide_space:
    mov eax, [rdi]
.space_byte:
    cmp eax, 32                  ; space
    je .skip_space
    lea rcx, [rax - 9]            ; tab, newline, VT, FF, CR
    cmp rcx, 4
    ja .sign
.skip_space:
    add rdi, rsi
    jmp .space
.sign:
    cmp eax, 45                  ; '-'
    jne .plus
    mov qword [rsp + 24], 1
    add rdi, rsi
    jmp .base
.plus:
    cmp eax, 43                  ; '+'
    jne .base
    add rdi, rsi

.base:
    cmp esi, 4
    je .wide_zero
    cmp byte [rdi], 48            ; '0'
    jmp .base_zero
.wide_zero:
    cmp dword [rdi], 48
.base_zero:
    jne .decimal_if_auto
    test r9, r9
    jz .octal_if_no_prefix
    cmp r9, 16
    jne .limit
    jmp .hex_prefix
.octal_if_no_prefix:
    mov r9d, 8
.hex_prefix:
    cmp esi, 4
    je .wide_prefix_letter
    movzx ecx, byte [rdi + rsi]
    jmp .prefix_letter
.wide_prefix_letter:
    mov ecx, [rdi + rsi]
.prefix_letter:
    or ecx, 32
    cmp ecx, 120                 ; 'x' or 'X'
    jne .limit
    cmp esi, 4
    je .wide_prefix_digit
    movzx ecx, byte [rdi + rsi * 2]
    jmp .prefix_digit
.wide_prefix_digit:
    mov ecx, [rdi + rsi * 2]
.prefix_digit:
    lea rdx, [rcx - 48]
    cmp rdx, 9
    jbe .use_hex
    or ecx, 32
    lea rdx, [rcx - 97]
    cmp rdx, 5
    ja .limit
.use_hex:
    lea rdi, [rdi + rsi * 2]
    mov r9d, 16
    jmp .limit
.decimal_if_auto:
    test r9, r9
    jnz .limit
    mov r9d, 10

.limit:
    mov rax, -1                   ; UINT64_MAX
    test qword [rsp + 16], 1
    jnz .cutoff
    mov rax, 0x7fffffffffffffff    ; INT64_MAX magnitude
    cmp qword [rsp + 24], 0
    je .cutoff
    inc rax                      ; INT64_MIN magnitude
.cutoff:
    ; For limit = quotient * base + remainder, compare before multiplying.
    ; The verified base is in 2..36 and the numerator high word is zero.
    mov [rsp + 32], rax           ; limit
    xor edx, edx
    div r9
    mov [rsp + 40], rax           ; quotient
    mov [rsp + 48], rdx           ; remainder
    mov r8, rdi                   ; first possible digit
    xor r10d, r10d                ; accumulated magnitude
    xor r11d, r11d                ; overflow flag

.next:
    cmp esi, 4
    je .wide_digit
    movzx ecx, byte [rdi]
    jmp .digit_value
.wide_digit:
    mov ecx, [rdi]
.digit_value:
    lea rdx, [rcx - 48]           ; '0'..'9'
    cmp rdx, 9
    jbe .digit
    or ecx, 32
    lea rdx, [rcx - 87]           ; 'a'..'z' map to 10..35
    cmp rdx, 10
    jb .end_digits
    cmp rdx, 35
    ja .end_digits
.digit:
    cmp rdx, r9
    jae .end_digits
    add rdi, rsi
    test r11d, r11d
    jnz .next                    ; consume the remaining digits after overflow
    cmp r10, [rsp + 40]
    ja .overflow
    jb .accumulate
    cmp rdx, [rsp + 48]
    ja .overflow
.accumulate:
    imul r10, r9
    add r10, rdx
    jmp .next
.overflow:
    mov r11d, 1
    jmp .next

.end_digits:
    cmp rdi, r8
    je .zero_result
    mov rsi, [rsp + 8]
    test rsi, rsi
    jz .result
    mov [rsi], rdi
.result:
    test r11d, r11d
    jnz .saturate
    mov rax, r10
    cmp qword [rsp + 24], 0
    je .done
    neg rax
    jmp .done

.saturate:
    mov rax, [rsp + 32]
    ; The saved negative signed limit has the INT64_MIN bit pattern.
    mov edi, 34                   ; ERANGE
    jmp .report_error
.zero_result:
    mov rsi, [rsp + 8]
    test rsi, rsi
    jz .no_endptr
    mov rdi, [rsp]
    mov [rsi], rdi
.no_endptr:
    xor eax, eax
    mov edi, 22                   ; EINVAL
.report_error:
    test qword [rsp + 16], 2
    jnz .done
    mov [rsp + 56], rax
    mov [rsp], edi
    call __errno_location
    mov edx, [rsp]
    mov [rax], edx
    mov rax, [rsp + 56]
.done:
    add rsp, 64
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
