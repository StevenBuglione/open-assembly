; Original integer scanf interpreter.
; rdi = input, rsi = format, rdx = va_list, rcx = 0 string / 1 FILE.
bits 64
default rel

global __al_vscan:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stdio_errno:function
extern __al_fmt_decimal:function
extern __al_scan_peek:function
extern __al_scan_take:function
extern __al_scan_space:function
extern __al_scan_set:function
extern __al_scan_chars:function
extern __al_scan_number:function
extern __al_scan_store:function
extern __al_va_next:function
extern isspace:function
extern malloc:function
extern free:function
extern memcpy:function

section .text.__al_vscan alloc exec nowrite progbits
__al_vscan:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72
    mov [rsp], rdi
    mov [rsp + 8], rcx
    mov rbx, rsi
    mov r12, rdx
    xor r14d, r14d                ; assignments
    xor r15d, r15d                ; completed conversion
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    lea r13, [rel input]
    mov rax, [rsp]
    mov [r13], rax
    mov rax, [rsp + 8]
    mov [r13 + 8], rax
    mov qword [r13 + 16], 0       ; bytes consumed
    mov qword [r13 + 24], -2      ; no peeked byte

.next:
    movzx edi, byte [rbx]
    test edi, edi
    jz .finish
    cmp edi, 37
    je .conversion
    call isspace
    test eax, eax
    jz .literal
    inc rbx
    mov rdi, r13
    call __al_scan_space
    jmp .next
.literal:
    mov rdi, r13
    call __al_scan_peek
    test rax, rax
    js .input_failure
    cmp al, [rbx]
    jne .finish
    inc rbx
    mov rdi, r13
    call __al_scan_take
    jmp .next

.conversion:
    inc rbx
    cmp byte [rbx], 37
    jne .fields
    mov rdi, r13
    call __al_scan_space
    jmp .literal
.fields:
    mov qword [rsp + 16], -1      ; unlimited width
    mov qword [rsp + 24], 0       ; suppression
    mov qword [rsp + 32], 4       ; integer destination width
    cmp byte [rbx], 42
    jne .width
    inc rbx
    mov qword [rsp + 24], 1
.width:
    mov rdi, rbx
    call __al_fmt_decimal
    cmp rdx, rbx
    je .length
    test rax, rax
    jz .invalid
    mov [rsp + 16], rax
    mov rbx, rdx
.length:
    movzx eax, byte [rbx]
    cmp eax, 104
    je .short
    cmp eax, 108
    je .long
    cmp eax, 106
    je .one_long
    cmp eax, 122
    je .one_long
    cmp eax, 116
    je .one_long
    jmp .specifier
.short:
    inc rbx
    mov qword [rsp + 32], 2
    cmp byte [rbx], 104
    jne .specifier
    inc rbx
    mov qword [rsp + 32], 1
    jmp .specifier
.long:
    inc rbx
    cmp byte [rbx], 108
    jne .long_size
.one_long:
    inc rbx
.long_size:
    mov qword [rsp + 32], 8
.specifier:
    movzx eax, byte [rbx]
    test eax, eax
    jz .invalid
    inc rbx
    cmp eax, 110
    je .count
    cmp eax, 99
    je .characters
    cmp eax, 115
    je .string
    cmp eax, 91
    je .brackets
    cmp eax, 105
    je .auto
    cmp eax, 111
    je .octal
    cmp eax, 120
    je .hex
    cmp eax, 88
    je .hex
    cmp eax, 112
    je .pointer
    cmp eax, 100
    je .decimal
    cmp eax, 117
    jne .invalid
.decimal:
    mov qword [rsp + 40], 10
    jmp .number
.auto:
    mov qword [rsp + 40], 0
    jmp .number
.octal:
    mov qword [rsp + 40], 8
    jmp .number
.pointer:
    mov qword [rsp + 32], 8
.hex:
    mov qword [rsp + 40], 16
.number:
    mov rdi, r13
    call __al_scan_space
    mov rdi, r13
    mov rsi, [rsp + 16]
    mov rdx, [rsp + 40]
    call __al_scan_number
    test edx, edx
    jnz .number_failure
    cmp qword [rsp + 24], 0
    jne .completed
    mov [rsp + 64], rax
    mov rdi, r12
    call __al_va_next
    mov rdi, rax
    mov rsi, [rsp + 32]
    mov rdx, [rsp + 64]
    call __al_scan_store
    inc r14d
    jmp .completed
.number_failure:
    cmp edx, 2
    je .input_failure
    jmp .finish
.count:
    cmp qword [rsp + 24], 0
    jne .completed
    mov rdi, r12
    call __al_va_next
    mov rdi, rax
    mov rsi, [rsp + 32]
    mov rdx, [r13 + 16]
    call __al_scan_store
    jmp .completed

.characters:
    mov qword [rsp + 40], 0
    cmp qword [rsp + 16], -1
    jne .byte_field
    mov qword [rsp + 16], 1
    jmp .byte_field
.string:
    mov qword [rsp + 40], 1
    mov rdi, r13
    call __al_scan_space
    jmp .byte_field
.brackets:
    mov qword [rsp + 40], 2
    mov rdi, rbx
    lea rsi, [rel scan_set]
    call __al_scan_set
    test rax, rax
    jz .invalid
    mov rbx, rax
.byte_field:
    cmp qword [rsp + 32], 4
    jne .invalid
    mov qword [rsp + 48], 0       ; destination or suppressed
    mov qword [rsp + 56], 0       ; optional temporary %c array
    cmp qword [rsp + 24], 0
    jne .scan_bytes
    mov rdi, r12
    call __al_va_next
    mov [rsp + 48], rax
    cmp qword [rsp + 40], 0
    jne .scan_bytes
    cmp qword [rsp + 16], 1
    je .scan_bytes
    mov rdi, [rsp + 16]
    call malloc
    test rax, rax
    jz .input_failure
    mov [rsp + 56], rax
.scan_bytes:
    mov rsi, [rsp + 56]
    test rsi, rsi
    jnz .byte_destination
    mov rsi, [rsp + 48]
.byte_destination:
    mov rdi, r13
    mov rdx, [rsp + 16]
    mov rcx, [rsp + 40]
    lea r8, [rel scan_set]
    call __al_scan_chars
    mov [rsp + 64], eax
    mov rsi, [rsp + 56]
    test rsi, rsi
    jz .byte_result
    test eax, eax
    jnz .release_temp
    mov rdi, [rsp + 48]
    mov rdx, [rsp + 16]
    call memcpy
.release_temp:
    mov rdi, [rsp + 56]
    call free
.byte_result:
    mov eax, [rsp + 64]
    cmp eax, 2
    je .input_failure
    test eax, eax
    jnz .finish
    cmp qword [rsp + 24], 0
    jne .completed
    inc r14d
.completed:
    mov r15d, 1
    jmp .next

.invalid:
    mov edi, 22
    call __al_stdio_errno
.input_failure:
    test r15d, r15d
    jnz .finish
    mov r14d, -1
.finish:
    cmp qword [r13 + 8], 0
    je .unlock
    mov rax, [r13 + 24]
    test rax, rax
    js .unlock
    mov rdi, [r13]
    mov [rdi + 72], rax           ; preserve one nonmatching lookahead byte
    and qword [rdi + 8], -17
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov eax, r14d
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .bss.__al_vscan alloc noexec write nobits align=8
input:
    resq 5
scan_set:
    resb 256

section .note.GNU-stack noalloc noexec nowrite progbits
