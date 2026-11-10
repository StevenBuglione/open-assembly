; Original baseline atomic object operation. rdi = size, rsi = object,
; rdx = input or expected, rcx = output or desired, r8d = operation.
; Operations: 0 load (output in rcx), 1 store, 2 exchange, 3 compare exchange.
; Only compare exchange has an observed return value (0/1 in eax).
bits 64
default rel

global __al_atomic_bytes:function
global __al_atomic_mutex:data
extern __al_lock:function
extern __al_unlock:function

section .text.__al_atomic_bytes alloc exec nowrite progbits
__al_atomic_bytes:
    test rdi, rdi
    jz .equal
    cmp rdi, 8
    ja .locked
    lea r9, [rdi - 1]
    test r9, rdi
    jnz .locked
    test r9, rsi
    jnz .locked
    cmp edi, 1
    je .byte
    cmp edi, 2
    je .word
    cmp edi, 4
    je .dword

.qword:
    test r8d, r8d
    jz .load_qword
    cmp r8d, 3
    je .compare_qword
    mov rax, [rdx]
    xchg qword [rsi], rax
    cmp r8d, 2
    jne .return
    mov [rcx], rax
    ret
.load_qword:
    mov rax, [rsi]
    mov [rcx], rax
    ret
.compare_qword:
    mov rax, [rdx]
    mov r9, [rcx]
    lock cmpxchg qword [rsi], r9
    je .equal
    mov [rdx], rax
    jmp .unequal

.dword:
    test r8d, r8d
    jz .load_dword
    cmp r8d, 3
    je .compare_dword
    mov eax, [rdx]
    xchg dword [rsi], eax
    cmp r8d, 2
    jne .return
    mov [rcx], eax
    ret
.load_dword:
    mov eax, [rsi]
    mov [rcx], eax
    ret
.compare_dword:
    mov eax, [rdx]
    mov r9d, [rcx]
    lock cmpxchg dword [rsi], r9d
    je .equal
    mov [rdx], eax
    jmp .unequal

.word:
    test r8d, r8d
    jz .load_word
    cmp r8d, 3
    je .compare_word
    mov ax, [rdx]
    xchg word [rsi], ax
    cmp r8d, 2
    jne .return
    mov [rcx], ax
    ret
.load_word:
    mov ax, [rsi]
    mov [rcx], ax
    ret
.compare_word:
    mov ax, [rdx]
    mov r9w, [rcx]
    lock cmpxchg word [rsi], r9w
    je .equal
    mov [rdx], ax
    jmp .unequal

.byte:
    test r8d, r8d
    jz .load_byte
    cmp r8d, 3
    je .compare_byte
    mov al, [rdx]
    xchg byte [rsi], al
    cmp r8d, 2
    jne .return
    mov [rcx], al
    ret
.load_byte:
    mov al, [rsi]
    mov [rcx], al
    ret
.compare_byte:
    mov al, [rdx]
    mov r9b, [rcx]
    lock cmpxchg byte [rsi], r9b
    je .equal
    mov [rdx], al
.unequal:
    xor eax, eax
.return:
    ret
.equal:
    mov eax, 1
    ret

.locked:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi                  ; positive size
    mov r12, rsi                  ; atomic object
    mov r13, rdx                  ; input or expected
    mov r14, rcx                  ; output or desired
    mov r15d, r8d
    lea rdi, [rel __al_atomic_mutex]
    call __al_lock

    cmp r15d, 3
    je .locked_compare
    cmp r15d, 2
    je .locked_exchange
    test r15d, r15d
    jz .locked_load
    mov rdi, r12
    mov rsi, r13
    jmp .copy
.locked_load:
    mov rdi, r14
    mov rsi, r12
    jmp .copy

.locked_compare:
    xor ecx, ecx
.compare_next:
    mov al, [r12 + rcx]
    cmp al, [r13 + rcx]
    jne .locked_unequal
    inc rcx
    cmp rcx, rbx
    jb .compare_next
    mov rdi, r12
    mov rsi, r14
    mov r15d, 1
    jmp .copy
.locked_unequal:
    mov rdi, r13
    mov rsi, r12
    xor r15d, r15d
.copy:
    xor ecx, ecx
.copy_next:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    cmp rcx, rbx
    jb .copy_next
    jmp .unlock

.locked_exchange:
    xor ecx, ecx
    mov r10d, 1
    cmp r14, r13
    jbe .exchange_next
    lea rcx, [rbx - 1]           ; output may overlap a later input byte
    mov r10, -1
.exchange_next:
    mov al, [r13 + rcx]
    mov dl, [r12 + rcx]
    mov [r12 + rcx], al
    mov [r14 + rcx], dl
    add rcx, r10
    dec rbx
    jnz .exchange_next
.unlock:
    lea rdi, [rel __al_atomic_mutex]
    call __al_unlock
    mov eax, r15d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_atomic_bytes alloc noexec write nobits align=4
__al_atomic_mutex:
    resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
