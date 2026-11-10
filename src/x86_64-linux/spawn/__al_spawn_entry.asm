; Original parent entry for explicit-path and PATH-search spawn.
bits 64
default rel

global __al_spawn_entry:function
extern __errno_location:function
extern malloc:function
extern free:function
extern __al_spawn_run:function
extern __al_exec_path_env:function

section .text.__al_spawn_entry alloc exec nowrite progbits
__al_spawn_entry:
    mov r10, [rsp + 8]            ; PATH-search flag passed as seventh argument
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 64
    mov [rsp], rdi                ; pid output
    mov [rsp + 8], rsi            ; executable path
    mov [rsp + 16], rdx           ; optional file actions
    mov [rsp + 24], rcx           ; optional attributes
    mov [rsp + 32], r8            ; argv
    mov [rsp + 40], r9
    mov [rsp + 48], r10            ; envp
    call __errno_location
    mov r12, rax
    mov r13d, [rax]
    mov edi, 128                  ; parent-owned workspace, inherited by child
    cmp qword [rsp + 48], 0
    je .allocate
    add edi, 4096                 ; extra candidate bytes for child search
.allocate:
    call malloc
    test rax, rax
    jz .no_memory
    mov rbx, rax
    mov rax, [rsp + 8]
    mov [rbx], rax
    mov rax, [rsp + 32]
    mov [rbx + 8], rax
    mov rax, [rsp + 40]
    mov [rbx + 16], rax
    mov rax, [rsp + 16]
    test rax, rax
    jz .actions_ready
    mov rax, [rax]                ; first action
.actions_ready:
    mov [rbx + 24], rax
    mov rax, [rsp + 24]
    test rax, rax
    jz .attributes_ready
    mov rax, [rax]                ; attribute state
.attributes_ready:
    mov [rbx + 32], rax
    mov rax, [rsp]
    mov [rbx + 40], rax
    xor eax, eax
    cmp qword [rsp + 48], 0
    je .path_ready
    call __al_exec_path_env
.path_ready:
    mov [rbx + 56], rax
    mov rdi, rbx
    call __al_spawn_run
    mov r14d, eax
    mov rdi, rbx
    call free
    jmp .restore
.no_memory:
    mov r14d, 12                  ; ENOMEM
.restore:
    mov [r12], r13d
    mov eax, r14d
    add rsp, 64
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
