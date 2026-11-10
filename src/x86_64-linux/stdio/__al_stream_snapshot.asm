; Original registry snapshot. Return a pinned pointer vector and its
; count in RAX/RDX. Return null with count -1 on allocation failure.
bits 64
default rel

global __al_stream_snapshot:function
extern __al_stdio_lock:data
extern __al_streams:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stdio_errno:function
extern malloc:function

section .text.__al_stream_snapshot alloc exec nowrite progbits
__al_stream_snapshot:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov rbx, [rel __al_streams]
    xor r12d, r12d
    xor r13d, r13d
.count:
    test rbx, rbx
    jz .allocate
    inc r12
    mov rbx, [rbx + 16]
    jmp .count
.allocate:
    test r12, r12
    jz .unlock
    mov rax, 0x1fffffffffffffff
    cmp r12, rax
    ja .overflow
    lea rdi, [r12*8]
    call malloc
    test rax, rax
    jz .error
    mov r13, rax
    mov rbx, [rel __al_streams]
    xor r14d, r14d
.pin:
    mov [r13 + r14*8], rbx
    add dword [rbx + 100], 1
    inc r14
    mov rbx, [rbx + 16]
    test rbx, rbx
    jnz .pin
    jmp .unlock
.overflow:
    mov edi, 12                  ; ENOMEM
    call __al_stdio_errno
.error:
    mov r12, -1
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov rax, r13
    mov rdx, r12
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
