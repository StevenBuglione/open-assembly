; Original shared lifecycle claim, wait and result retrieval.
bits 64
default rel

global __al_thread_join:function
extern pthread_self:function
extern __al_thread_reap:function

section .text.__al_thread_join alloc exec nowrite progbits
__al_thread_join:
    push rbx
    mov rbx, rdi
    call pthread_self
    cmp rax, rbx
    je .self
    mov eax, [rbx + 0x74]
.claim:
    cmp eax, 1                    ; open or exiting open
    ja .invalid
    mov edx, 2                    ; claimed
    lock cmpxchg dword [rbx + 0x74], edx
    jnz .claim
    mov rdi, rbx
    call __al_thread_reap
    mov rdx, rax                  ; result accompanies success status
    xor eax, eax
    jmp .done
.self:
    mov eax, 35                   ; EDEADLK
    jmp .done
.invalid:
    mov eax, 22
.done:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
