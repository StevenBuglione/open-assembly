; Original thread-specific value cleanup. rdi = this thread's descriptor.
bits 64
default rel

global __al_tsd_destruct:function
extern __al_tsd_keys:data
extern __al_tsd_lock:data
extern __al_lock:function
extern __al_unlock:function

section .text.__al_tsd_destruct alloc exec nowrite progbits
__al_tsd_destruct:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    lea r13, [rel __al_tsd_keys]
    mov dword [rsp], 4
.pass:
    mov dword [rsp + 4], 0
    xor r12d, r12d
.scan:
    mov r14, [rbx + r12 + 0x118]
    test r14, r14
    jz .next
    lea rdi, [rel __al_tsd_lock]
    call __al_lock
    mov rax, [r13 + r12]
    test al, 1
    jz .skip
    cmp rax, [rbx + r12 + 0x110]
    jne .skip
    mov r15, [r13 + r12 + 8]
    test r15, r15
    jz .skip
    mov qword [rbx + r12 + 0x118], 0
    lea rdi, [rel __al_tsd_lock]
    call __al_unlock
    mov rdi, r14
    mov rax, r15
    call rax
    mov dword [rsp + 4], 1
    jmp .next
.skip:
    lea rdi, [rel __al_tsd_lock]
    call __al_unlock
.next:
    add r12, 16
    cmp r12, 2048
    jb .scan
    cmp dword [rsp + 4], 0
    je .done
    dec dword [rsp]
    jnz .pass
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
