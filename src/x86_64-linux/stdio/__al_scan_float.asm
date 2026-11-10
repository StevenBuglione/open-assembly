; Original streaming floating input item scanner.
; rdi = scan context, rsi = width, rdx = target, rcx = destination or NULL.
; eax = 0 success, 1 matching failure, 2 input failure.
bits 64
default rel

global __al_scan_float:function
extern __al_scan_peek:function
extern __al_scan_take:function
extern __al_float_lex:function
extern __al_strtof_core:function
extern __al_stdio_errno:function
extern malloc:function
extern realloc:function
extern memcpy:function
extern free:function

section .text.__al_scan_float alloc exec nowrite progbits
__al_scan_float:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 104
    mov rbx, rdi
    mov r12, rsi                  ; width remaining
    mov r13, rdx                  ; result format
    mov r14, rcx                  ; nullable output
    xor r15d, r15d                ; token state
    lea rax, [rel short_token]
    mov [rsp + 8], rax
    mov qword [rsp + 16], 0       ; token length
    mov qword [rsp + 24], 256     ; token capacity
    mov qword [rsp + 32], 0       ; allocated token
    mov qword [rsp + 56], 10      ; radix
    mov qword [rsp + 64], 0       ; radix point seen
    mov qword [rsp + 72], 0       ; significand digit seen

.next:
    cmp r15, 10
    je .finish
    test r12, r12
    jz .finish
    mov rdi, rbx
    call __al_scan_peek
    test rax, rax
    js .end_input
    mov [rsp + 80], eax
    test r15, r15
    jz .sign
    cmp r15, 1
    je .first
    cmp r15, 2
    je .number
    cmp r15, 3
    je .prefix
    cmp r15, 4
    je .exp_sign
    cmp r15, 5
    je .exp_digits
    cmp r15, 6
    je .pattern
    cmp r15, 7
    je .inf_tail
    cmp r15, 8
    je .nan_tail
    jmp .payload

.sign:
    mov r15d, 1
    cmp eax, 43
    je .consume
    cmp eax, 45
    je .consume
.first:
    mov ecx, eax
    or ecx, 32
    cmp ecx, 105
    je .inf
    cmp ecx, 110
    je .nan
    cmp eax, 48
    jne .start_number
    mov qword [rsp + 72], 1
    mov r15d, 3
    jmp .consume
.start_number:
    mov r15d, 2
    jmp .number
.prefix:
    mov r15d, 2
    mov ecx, eax
    or ecx, 32
    cmp ecx, 120
    jne .number
    mov qword [rsp + 56], 16
    mov qword [rsp + 72], 0
    jmp .consume

.number:
    lea rcx, [rax - 48]
    cmp rcx, 9
    jbe .digit
    cmp eax, 46
    je .period
    or eax, 32
    cmp qword [rsp + 56], 16
    jne .decimal_marker
    lea rcx, [rax - 97]
    cmp rcx, 5
    jbe .digit
    cmp eax, 112
    jne .finish
    jmp .exp_marker
.decimal_marker:
    cmp eax, 101
    jne .finish
.exp_marker:
    cmp qword [rsp + 72], 0
    je .finish
    mov r15d, 4
    jmp .consume
.digit:
    mov qword [rsp + 72], 1
    jmp .consume
.period:
    cmp qword [rsp + 64], 0
    jne .finish
    mov qword [rsp + 64], 1
    jmp .consume
.exp_sign:
    mov r15d, 5
    cmp eax, 43
    je .consume
    cmp eax, 45
    je .consume
.exp_digits:
    lea rcx, [rax - 48]
    cmp rcx, 9
    jbe .consume
    jmp .finish

.inf:
    lea rcx, [rel inf_pattern]
    mov qword [rsp + 48], 7
    jmp .start_pattern
.nan:
    lea rcx, [rel nan_pattern]
    mov qword [rsp + 48], 8
    jmp .start_pattern
.inf_tail:
    mov ecx, eax
    or ecx, 32
    cmp ecx, 105
    jne .finish
    lea rcx, [rel infinity_tail]
    mov qword [rsp + 48], 10
.start_pattern:
    mov [rsp + 40], rcx
    mov r15d, 6
.pattern:
    or eax, 32
    mov rcx, [rsp + 40]
    movzx edx, byte [rcx]
    cmp eax, edx
    jne .finish
    inc rcx
    mov [rsp + 40], rcx
    cmp byte [rcx], 0
    jne .consume
    mov r15, [rsp + 48]
    jmp .consume
.nan_tail:
    cmp eax, 40
    jne .finish
    mov r15d, 9
    jmp .consume
.payload:
    cmp eax, 41
    je .close_payload
    cmp eax, 95
    je .consume
    lea rcx, [rax - 48]
    cmp rcx, 9
    jbe .consume
    or eax, 32
    lea rcx, [rax - 97]
    cmp rcx, 25
    jbe .consume
    jmp .finish
.close_payload:
    mov r15d, 10

.consume:
    mov rax, [rsp + 16]
    inc rax
    cmp rax, [rsp + 24]
    jb .append
    mov rsi, [rsp + 24]
    add rsi, rsi
    jc .capacity_error
    test rsi, rsi
    js .capacity_error
    mov [rsp + 24], rsi
    cmp qword [rsp + 32], 0
    je .new_buffer
    mov rdi, [rsp + 8]
    call realloc
    test rax, rax
    jz .input_failure
    mov [rsp + 8], rax
    jmp .append
.new_buffer:
    mov rdi, rsi
    call malloc
    test rax, rax
    jz .input_failure
    mov rdi, rax
    mov rsi, [rsp + 8]
    mov rdx, [rsp + 16]
    call memcpy
    mov [rsp + 8], rax
    mov qword [rsp + 32], 1
.append:
    mov rax, [rsp + 8]
    mov rcx, [rsp + 16]
    mov dl, [rsp + 80]
    mov [rax + rcx], dl
    inc qword [rsp + 16]
    mov rdi, rbx
    call __al_scan_take
    dec r12
    jmp .next

.end_input:
    cmp qword [rsp + 16], 0
    je .input_failure
.finish:
    mov rax, [rsp + 16]
    test rax, rax
    jz .matching_failure
    mov rdi, [rsp + 8]
    mov byte [rdi + rax], 0
    lea rsi, [rel validation_number]
    lea rdx, [rel validation_meta]
    mov ecx, 1
    call __al_float_lex           ; validate without rounding or raising flags
    test rax, rax
    js .matching_failure
    mov rax, [rsp + 8]
    add rax, [rsp + 16]
    cmp rax, [rel validation_meta]
    jne .matching_failure
    test r14, r14
    jz .success
    mov rdi, [rsp + 8]
    xor esi, esi
    mov rdx, r13
    call __al_strtof_core
    test r13, r13
    jz .store_float
    mov [r14], rax
    cmp r13, 2
    jne .success
    mov [r14 + 8], dx
    jmp .success
.store_float:
    mov [r14], eax
.success:
    xor eax, eax
    jmp .release
.matching_failure:
    mov eax, 1
    jmp .release
.capacity_error:
    mov edi, 12
    call __al_stdio_errno
.input_failure:
    mov eax, 2
.release:
    mov [rsp + 88], eax
    cmp qword [rsp + 32], 0
    je .done
    mov rdi, [rsp + 8]
    call free
.done:
    mov eax, [rsp + 88]
    add rsp, 104
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_scan_float alloc noexec nowrite progbits
inf_pattern:
    db "inf", 0
infinity_tail:
    db "inity", 0
nan_pattern:
    db "nan", 0

section .bss.__al_scan_float alloc noexec write nobits align=8
short_token:
    resb 256
validation_meta:
    resq 6
validation_number:
    resq 1281

section .note.GNU-stack noalloc noexec nowrite progbits
