; Original ENOEXEC fallback. Inputs: candidate, argv, envp.
; Build the shell argument vector only on the fallback path.
bits 64
default rel

global __al_exec_script:function
extern malloc:function
extern free:function
extern __al_execve_raw:function

section .text.__al_exec_script alloc exec nowrite progbits
__al_exec_script:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor r14d, r14d
    cmp qword [r12], 0
    je .allocate
    add r12, 8
    mov rax, 0x1ffffffffffffffb  ; maximum count allowing four extra pointers
.count:
    cmp qword [r12 + r14*8], 0
    je .allocate
    cmp r14, rax
    jae .too_large
    inc r14
    jmp .count
.allocate:
    lea rdi, [r14*8 + 32]
    call malloc
    test rax, rax
    jz .no_memory
    mov r15, rax
    lea rdi, [rel shell_path]
    mov [rax], rdi
    lea rdx, [rel option_end]
    mov [rax + 8], rdx
    mov [rax + 16], rbx
    xor ecx, ecx
.copy:
    cmp rcx, r14
    jae .end_vector
    mov rdx, [r12 + rcx*8]
    mov [rax + rcx*8 + 24], rdx
    inc rcx
    jmp .copy
.end_vector:
    mov qword [rax + r14*8 + 24], 0
    mov rsi, rax
    mov rdx, r13
    call __al_execve_raw
    mov r14, rax
    mov rdi, r15
    call free
    mov rax, r14
    jmp .done
.too_large:
    mov rax, -7                   ; E2BIG
    jmp .done
.no_memory:
    mov rax, -12                  ; ENOMEM
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_exec_script alloc noexec nowrite progbits
shell_path: db "/bin/sh", 0
option_end: db "--", 0

section .note.GNU-stack noalloc noexec nowrite progbits
