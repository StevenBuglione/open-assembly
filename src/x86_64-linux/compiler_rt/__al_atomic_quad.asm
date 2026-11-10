; Original locked 16-byte operation. rdi = object, rdx:rsi = operand,
; ecx = operation, r8 = expected pointer for compare exchange.
; 0 add, 1 subtract, 2 AND, 3 OR, 4 XOR, 5 NAND (all fetch original).
; 6 load, 7 store/exchange, 8 compare exchange (strong, boolean result).
; Loads and exchanges return the original representation in rdx:rax.
bits 64
default rel

global __al_atomic_quad:function
extern __al_atomic_mutex:data
extern __al_lock:function
extern __al_unlock:function

section .text.__al_atomic_quad alloc exec nowrite progbits
__al_atomic_quad:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    mov r15, r8
    lea rdi, [rel __al_atomic_mutex]
    call __al_lock

    mov rax, [rbx]
    mov rdx, [rbx + 8]
    mov [rsp], rax
    mov [rsp + 8], rdx
    test r14d, r14d
    jz .add
    cmp r14d, 1
    je .subtract
    cmp r14d, 3
    je .or
    cmp r14d, 4
    je .xor
    cmp r14d, 6
    je .unlock
    cmp r14d, 7
    je .replace
    cmp r14d, 8
    je .compare
    and rax, r12
    and rdx, r13
    cmp r14d, 2
    je .publish
    not rax
    not rdx
    jmp .publish
.add:
    add rax, r12
    adc rdx, r13
    jmp .publish
.subtract:
    sub rax, r12
    sbb rdx, r13
    jmp .publish
.or:
    or rax, r12
    or rdx, r13
    jmp .publish
.xor:
    xor rax, r12
    xor rdx, r13
    jmp .publish
.compare:
    cmp [r15], rax
    jne .different
    cmp [r15 + 8], rdx
    jne .different
    mov qword [rsp], 1
    jmp .replace
.different:
    mov [r15], rax
    mov [r15 + 8], rdx
    mov qword [rsp], 0
    jmp .unlock
.replace:
    mov rax, r12
    mov rdx, r13
.publish:
    mov [rbx], rax
    mov [rbx + 8], rdx
.unlock:
    lea rdi, [rel __al_atomic_mutex]
    call __al_unlock
    mov rax, [rsp]
    mov rdx, [rsp + 8]
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
