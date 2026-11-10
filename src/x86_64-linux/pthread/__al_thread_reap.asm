; Original wait and reclaim for the sole lifecycle claimant.
; Input: target descriptor. Returns the published result after reclamation.
bits 64
default rel

global __al_thread_reap:function
extern __al_futex:function
extern __al_thread_dispose:function
extern __al_panic:function

section .text.__al_thread_reap alloc exec nowrite progbits
__al_thread_reap:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
.wait:
    mov edx, [rbx + 0x70]
    test edx, edx
    jz .terminated
    lea rdi, [rbx + 0x70]
    xor esi, esi                  ; FUTEX_WAIT pairs with the kernel's wake
    call __al_futex
    test rax, rax
    jz .wait
    cmp rax, -4
    je .wait
    cmp rax, -11
    je .wait
    lea rdi, [rel failure]
    mov esi, 36
    call __al_panic
    ud2
.terminated:
    mov r12, [rbx + 0x78]
    mov rdi, rbx
    call __al_thread_dispose
    mov rax, r12
    add rsp, 8
    pop r12
    pop rbx
    ret

section .rodata.__al_thread_reap alloc noexec nowrite progbits
failure: db "open-assembly: cannot reap a thread", 10

section .note.GNU-stack noalloc noexec nowrite progbits
