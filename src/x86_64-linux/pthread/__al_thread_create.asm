; Original shared Linux thread creation and start-mode publication.
bits 64
default rel

global __al_thread_create:function
extern __al_tls_new:function
extern __al_thread_stack_new:function
extern __al_thread_clone:function
extern __al_thread_dispose:function
extern __al_thread_count:data
extern __al_tls_template:data

section .text.__al_thread_create alloc exec nowrite progbits
__al_thread_create:
    test rdi, rdi
    jz .invalid
    test rdx, rdx
    jz .invalid
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32
    mov rbx, rdi
    mov r13, rdx
    mov r14, rcx
    mov [rsp + 20], r8d            ; 0 pointer, 1 signed int
    test rsi, rsi
    jz .defaults
    cmp dword [rsi], 0x4f415448
    jne .invalid_attribute
    mov rax, [rsi + 8]
    cmp rax, 16384
    jb .invalid_attribute
    mov [rsp], rax
    mov rax, [rsi + 16]
    mov [rsp + 8], rax
    mov eax, [rsi + 24]
    cmp eax, 1
    ja .invalid_attribute
    mov [rsp + 16], eax
    jmp .allocate_tls
.defaults:
    mov qword [rsp], 1048576
    mov rax, [rel __al_tls_template + 48]
    mov [rsp + 8], rax
    mov dword [rsp + 16], 0
.allocate_tls:
    call __al_tls_new
    test rax, rax
    jz .memory
    mov r12, rax
    mov ecx, [rsp + 20]
    mov [r12 + 0x918], ecx
    mov rdi, [rsp]
    mov rsi, [rsp + 8]
    call __al_thread_stack_new
    test rax, rax
    jz .unmap_tls
    mov [r12 + 0x60], rax
    mov [r12 + 0x68], rdx
    cmp dword [rsp + 16], 0
    je .launch
    mov dword [r12 + 0x74], 3     ; detached before the child can exit
.launch:
    lea rsi, [rax + rdx - 16]
    mov [rsi], r13
    mov [rsi + 8], r14
    mov eax, 1
    lock xadd dword [rel __al_thread_count], eax
    mov rdi, r12
    lea rdx, [r12 + 0x70]
    call __al_thread_clone
    test rax, rax
    js .clone_error
    mov [rbx], r12
    cmp dword [rsp + 20], 1
    jne .started
    mov dword [r12 + 0x918], 2     ; publish C11 launch as final descriptor access
.started:
    xor eax, eax
    jmp .done
.clone_error:
    mov r13, rax
    mov eax, -1
    lock xadd dword [rel __al_thread_count], eax
    mov rdi, r12
    call __al_thread_dispose
    cmp r13, -1                   ; EPERM
    je .clone_errno
    cmp r13, -22                  ; EINVAL
    je .clone_errno
    cmp r13, -12                  ; ENOMEM
    jne .resource
.clone_errno:
    mov rax, r13
    neg eax
    jmp .done
.unmap_tls:
    mov rdi, r12
    call __al_thread_dispose
.memory:
    mov eax, 12                   ; ENOMEM, mapped to POSIX EAGAIN by its wrapper
    jmp .done
.resource:
    mov eax, 11                   ; EAGAIN
    jmp .done
.invalid_attribute:
    mov eax, 22
.done:
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
