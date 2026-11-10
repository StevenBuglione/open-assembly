; Original spawn action storage. rdi = object, rsi = kind, rdx = fd,
; rcx = extra fd or open flags, r8 = mode, r9 = optional copied path.
; Returns a positive error or zero and preserves errno.
bits 64
default rel

global __al_spawn_append:function
extern __errno_location:function
extern strlen:function
extern malloc:function
extern memcpy:function

section .text.__al_spawn_append alloc exec nowrite progbits
__al_spawn_append:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov [rsp], r8
    mov [rsp + 8], r9
    xor eax, eax
    test r9, r9
    jz .size
    mov rdi, r9
    call strlen
    inc rax                      ; include the path terminator
.size:
    mov [rsp + 16], rax
    call __errno_location
    mov [rsp + 24], rax
    mov edx, [rax]
    mov [rsp + 32], edx
    mov rdi, [rsp + 16]
    add rdi, 32                   ; fixed header precedes copied path
    jc .no_memory
    call malloc
    test rax, rax
    jz .no_memory
    mov r15, rax
    mov qword [rax], 0           ; next action
    mov [rax + 8], r12d
    mov [rax + 12], r13d
    mov [rax + 16], r14d
    mov edx, [rsp]
    mov [rax + 20], edx
    mov qword [rax + 24], 0
    mov rdx, [rsp + 16]
    test rdx, rdx
    jz .append
    lea rdi, [r15 + 32]
    mov rsi, [rsp + 8]
    call memcpy
.append:
    mov rax, [rbx + 8]
    test rax, rax
    jz .first
    mov [rax], r15
    jmp .tail
.first:
    mov [rbx], r15
.tail:
    mov [rbx + 8], r15
    xor eax, eax
    jmp .restore
.no_memory:
    mov eax, 12                   ; ENOMEM
.restore:
    mov rcx, [rsp + 24]
    mov edx, [rsp + 32]
    mov [rcx], edx
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
