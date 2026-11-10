; Square root of (rsi+r8)*(rdx+r8) into rdi. Scale rcx for bases and r9 for addend.
bits 64
default rel

global __al_complex_geometric_root:function
extern __al_fork_scratch_locks:data
extern __al_lock:function
extern __al_unlock:function
extern __al_big_copy:function
extern __al_big_multiply:function
extern __al_complex_scaled_add:function
extern __al_complex_scaled_sqrt:function

section .text.__al_complex_geometric_root alloc exec nowrite progbits
__al_complex_geometric_root:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov [rsp], r9
    lea rdi, [rel __al_fork_scratch_locks + 72]
    call __al_lock
    lea rdi, [rel low_factor]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel high_factor]
    mov rsi, r13
    call __al_big_copy
    lea rdi, [rel scratch]
    mov rsi, r15
    call __al_big_copy
    lea rdi, [rel low_factor]
    lea rsi, [rel scratch]
    mov rdx, r14
    mov rcx, [rsp]
    call __al_complex_scaled_add
    mov [rsp + 8], rax
    lea rdi, [rel scratch]
    mov rsi, r15
    call __al_big_copy
    lea rdi, [rel high_factor]
    lea rsi, [rel scratch]
    mov rdx, r14
    mov rcx, [rsp]
    call __al_complex_scaled_add
    add [rsp + 8], rax
    lea rdi, [rel scratch]
    lea rsi, [rel low_factor]
    lea rdx, [rel high_factor]
    call __al_big_multiply
    mov rdi, rbx
    lea rsi, [rel scratch]
    mov rdx, [rsp + 8]
    lea rcx, [rel remainder]
    lea r8, [rel trial]
    call __al_complex_scaled_sqrt
    mov rbx, rax
    lea rdi, [rel __al_fork_scratch_locks + 72]
    call __al_unlock
    mov rax, rbx
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss alloc noexec write nobits
alignb 16
    resd 1                    ; preserve scratch record offsets
alignb 16
low_factor: resb 10248
high_factor: resb 10248
scratch: resb 10248
remainder: resb 10248
trial: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
