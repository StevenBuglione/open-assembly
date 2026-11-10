; Original integer format interpreter.
; rdi = sink, rsi = size for string output, rdx = format, rcx = va_list.
; r8 = 0 for a string sink or 1 for a FILE sink.
bits 64
default rel

global __al_vformat:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_va_next:function
extern __al_fmt_decimal:function
extern __al_fmt_emit:function
extern __al_fmt_integer:function
extern __al_fmt_text:function
extern __al_stdio_errno:function
extern strlen:function

section .text.__al_vformat alloc exec nowrite progbits
__al_vformat:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov [rsp], rdi
    mov [rsp + 8], rsi
    mov [rsp + 16], r8
    mov rbx, rdx                  ; format cursor
    mov r12, rcx                  ; variadic cursor
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    lea r13, [rel output]
    lea r15, [rel fields]
    mov rax, [rsp]
    mov [r13], rax
    mov rax, [rsp + 16]
    mov [r13 + 24], rax           ; sink kind
    mov qword [r13 + 16], 0       ; full output count
    mov rax, [rsp + 8]
    mov [r13 + 40], rax           ; original destination capacity
    test rax, rax
    jz .capacity
    dec rax
.capacity:
    mov [r13 + 8], rax

.next:
    cmp byte [rbx], 0
    je .success
    cmp byte [rbx], 37
    je .conversion
    mov rsi, rbx
    xor edx, edx
.literal:
    inc rbx
    inc rdx
    cmp byte [rbx], 0
    je .emit
    cmp byte [rbx], 37
    jne .literal
.emit:
    mov rdi, r13
    xor ecx, ecx
    call __al_fmt_emit
    test eax, eax
    jz .next
    jmp .failure

.conversion:
    inc rbx
    cmp byte [rbx], 37
    jne .start_fields
    mov rsi, rbx
    inc rbx
    mov edx, 1
    jmp .emit
.start_fields:
    mov qword [r15], 0            ; flags
    mov qword [r15 + 16], -1      ; absent precision
    mov qword [r15 + 24], 4       ; default promoted integer size
.flags:
    movzx eax, byte [rbx]
    cmp eax, 45
    je .left
    cmp eax, 43
    je .plus
    cmp eax, 32
    je .space
    cmp eax, 35
    je .alternate
    cmp eax, 48
    jne .width
    or qword [r15], 16
    jmp .flag_next
.left:
    or qword [r15], 1
    jmp .flag_next
.plus:
    or qword [r15], 2
    jmp .flag_next
.space:
    or qword [r15], 4
    jmp .flag_next
.alternate:
    or qword [r15], 8
.flag_next:
    inc rbx
    jmp .flags

.width:
    cmp byte [rbx], 42
    jne .literal_width
    inc rbx
    mov rdi, r12
    call __al_va_next
    movsxd rax, eax
    test rax, rax
    jns .width_ready
    or qword [r15], 1
    neg rax
    jmp .width_ready
.literal_width:
    mov rdi, rbx
    call __al_fmt_decimal
    mov rbx, rdx
.width_ready:
    cmp rax, 2147483647
    ja .overflow
    mov [r15 + 8], rax
    cmp byte [rbx], 46
    jne .length
    inc rbx
    cmp byte [rbx], 42
    jne .literal_precision
    inc rbx
    mov rdi, r12
    call __al_va_next
    movsxd rax, eax
    test rax, rax
    js .length
    jmp .save_precision
.literal_precision:
    mov rdi, rbx
    call __al_fmt_decimal
    mov rbx, rdx
.save_precision:
    mov [r15 + 16], rax
.length:
    movzx eax, byte [rbx]
    cmp eax, 104                  ; h or hh
    je .short
    cmp eax, 108                  ; l or ll
    je .long
    cmp eax, 106                  ; j
    je .one_long
    cmp eax, 122                  ; z
    je .one_long
    cmp eax, 116                  ; t
    je .one_long
    jmp .specifier
.short:
    inc rbx
    mov qword [r15 + 24], 2
    cmp byte [rbx], 104
    jne .specifier
    inc rbx
    mov qword [r15 + 24], 1
    jmp .specifier
.long:
    inc rbx
    cmp byte [rbx], 108
    jne .long_size
.one_long:
    inc rbx
.long_size:
    mov qword [r15 + 24], 8
.specifier:
    movzx eax, byte [rbx]
    mov [r15 + 32], rax
    test eax, eax
    jz .invalid
    inc rbx
    cmp eax, 99
    je .character
    cmp eax, 115
    je .string
    cmp eax, 110
    je .store_count
    cmp eax, 100
    je .integer
    cmp eax, 105
    je .integer
    cmp eax, 111
    je .integer
    cmp eax, 117
    je .integer
    cmp eax, 120
    je .integer
    cmp eax, 88
    je .integer
    cmp eax, 112
    jne .invalid
.integer:
    mov rdi, r12
    call __al_va_next
    mov rdi, r13
    mov rsi, r15
    mov rdx, rax
    call __al_fmt_integer
    test eax, eax
    jz .next
    jmp .failure

.character:
    cmp qword [r15 + 24], 4
    jne .invalid
    mov rdi, r12
    call __al_va_next
    mov [r13 + 32], al
    lea rdx, [r13 + 32]
    mov ecx, 1
    jmp .emit_text
.string:
    cmp qword [r15 + 24], 4
    jne .invalid
    mov rdi, r12
    call __al_va_next
    mov r14, rax
    test r14, r14
    jnz .string_length
    lea r14, [rel null_text]
.string_length:
    mov r8, [r15 + 16]
    test r8, r8
    js .unbounded
    xor ecx, ecx
.bounded:
    cmp rcx, r8
    jae .string_ready
    cmp byte [r14 + rcx], 0
    je .string_ready
    inc rcx
    jmp .bounded
.unbounded:
    mov rdi, r14
    call strlen
    mov rcx, rax
.string_ready:
    mov rdx, r14
.emit_text:
    mov rdi, r13
    mov rsi, r15
    call __al_fmt_text
    test eax, eax
    jz .next
    jmp .failure
.store_count:
    mov rdi, r12
    call __al_va_next
    mov rcx, [r13 + 16]
    cmp qword [r15 + 24], 8
    je .count_long
    cmp qword [r15 + 24], 4
    je .count_int
    cmp qword [r15 + 24], 2
    je .count_short
    mov [rax], cl
    jmp .next
.count_short:
    mov [rax], cx
    jmp .next
.count_int:
    mov [rax], ecx
    jmp .next
.count_long:
    mov [rax], rcx
    jmp .next

.invalid:
    mov edi, 22
    jmp .errno
.overflow:
    mov edi, 75
.errno:
    call __al_stdio_errno
.failure:
    mov r14d, -1
    jmp .terminate
.success:
    mov r14d, [r13 + 16]
.terminate:
    cmp qword [r13 + 24], 0
    jne .unlock
    cmp qword [r13 + 40], 0
    je .unlock
    mov rax, [r13 + 16]
    cmp rax, [r13 + 8]
    jbe .nul
    mov rax, [r13 + 8]
.nul:
    mov rcx, [r13]
    mov byte [rcx + rax], 0
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov eax, r14d
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_vformat alloc noexec nowrite progbits
null_text:
    db "(null)", 0

section .bss.__al_vformat alloc noexec write nobits align=8
output:
    resb 128
fields:
    resq 5

section .note.GNU-stack noalloc noexec nowrite progbits
