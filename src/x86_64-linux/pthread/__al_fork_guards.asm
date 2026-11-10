; EDI zero acquires, one releases in parent, two clears in child.
bits 64
default rel

global __al_fork_guards:function
extern __al_fork_guard_at:function
extern __al_fork_scratch_reset:function
extern __al_lock:function
extern __al_unlock:function

section .text.__al_fork_guards alloc exec nowrite progbits
__al_fork_guards:
    push rbx
    push r12
    sub rsp, 8
    mov r12d, edi
    test r12d, r12d
    jnz .reverse
    xor ebx, ebx
.acquire:
    mov edi, ebx
    call __al_fork_guard_at
    mov rdi, rax
    call __al_lock
    inc ebx
    cmp ebx, 13
    jb .acquire
    jmp .return
.reverse:
    mov ebx, 12
.release:
    mov edi, ebx
    call __al_fork_guard_at
    cmp r12d, 2
    je .clear
    mov rdi, rax
    call __al_unlock
    jmp .previous
.clear:
    mov dword [rax], 0
.previous:
    dec ebx
    jns .release
    cmp r12d, 2
    jne .return
    call __al_fork_scratch_reset
.return:
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
