; Original handshake descriptor relocation. rdi = spawn workspace. A raw
; error leaves the original pipe owned by the caller. Success updates byte 52.
bits 64
default rel

global __al_spawn_reserve:function
extern __al_fcntl:function
extern close:function

section .text.__al_spawn_reserve alloc exec nowrite progbits
__al_spawn_reserve:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    movsxd r12, dword [rbx + 52] ; original write descriptor
    mov r13, r12                 ; candidate descriptor
    xor r14d, r14d               ; lowest descriptor to consider
.scan:
    mov rax, [rbx + 24]
.next:
    test rax, rax
    jz .reserved
    cmp r13d, [rax + 12]
    je .conflict
    cmp dword [rax + 8], 1       ; dup2 references a second descriptor
    jne .advance
    cmp r13d, [rax + 16]
    je .conflict
.advance:
    mov rax, [rax]
    jmp .next
.conflict:
    cmp r13, r12
    je .duplicate
    lea r14, [r13 + 1]
    mov rdi, r13
    call close
.duplicate:
    mov rdi, r12
    mov esi, 1030                ; F_DUPFD_CLOEXEC
    mov rdx, r14
    call __al_fcntl
    cmp rax, -4095
    jae .done
    mov r13, rax
    jmp .scan
.reserved:
    cmp r13, r12
    je .success
    mov [rbx + 52], r13d
    mov rdi, r12
    call close
.success:
    xor eax, eax
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
