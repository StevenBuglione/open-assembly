; Original condition wake. Inputs: condition and nonzero broadcast flag.
bits 64
default rel

global __al_cond_wake:function
extern __al_lock:function
extern __al_unlock:function
extern __al_futex:function
extern __al_panic:function

section .text.__al_cond_wake alloc exec nowrite progbits
__al_cond_wake:
    test rdi, rdi
    jz .invalid
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
    call __al_lock
    cmp dword [rbx + 12], 0
    jne .destroyed
.next:
    mov rdi, [rbx + 16]
    test rdi, rdi
    jz .unlock
    mov rax, [rdi]
    mov [rbx + 16], rax
    test rax, rax
    jnz .wake
    mov qword [rbx + 24], 0
.wake:
    add rdi, 8
    mov dword [rdi], 1
    mov esi, 129                 ; FUTEX_WAKE_PRIVATE
    mov edx, 1
    call __al_futex
    test rax, rax
    js .failure
    test r12, r12
    jnz .next
    jmp .unlock
.destroyed:
    mov r13d, 22
.unlock:
    mov rdi, rbx
    call __al_unlock
    mov eax, r13d
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, 22
    ret
.failure:
    lea rdi, [rel wake_error]
    mov esi, 43
    call __al_panic
    ud2

section .rodata.__al_cond_wake alloc noexec nowrite progbits
wake_error: db "open-assembly: condition futex wake failed", 10

section .note.GNU-stack noalloc noexec nowrite progbits
