; Original typed callback entry reached only on the new thread's stack.
bits 64
default rel

global __al_thread_start:function
extern pthread_self:function
extern pthread_exit:function
extern thrd_yield:function

section .text.__al_thread_start alloc exec nowrite progbits
__al_thread_start:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    call pthread_self
    mov r13, rax
.await_publication:
    cmp dword [r13 + 0x918], 1
    jne .start
    call thrd_yield
    jmp .await_publication
.start:
    mov rdi, r12
    mov rax, rbx
    call rax
    mov rdi, rax
    cmp dword [r13 + 0x918], 2
    jne .finish
    movsxd rdi, eax
.finish:
    call pthread_exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
