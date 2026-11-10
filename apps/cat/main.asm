; Original byte-copy utility. The runtime calls main with argc, argv, envp.
bits 64
default rel

global main:function
extern stdin:data
extern stdout:data
extern fopen:function
extern fread:function
extern fwrite:function
extern ferror:function
extern fclose:function
extern fflush:function
extern perror:function

section .text.main alloc exec nowrite progbits
main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    movsxd r12, edi
    dec r12
    lea rbx, [rsi + 8]
    xor r15d, r15d                ; process status
    test r12, r12
    jz .implicit
    mov rax, [rbx]
    cmp byte [rax], 45
    jne .operand
    cmp byte [rax + 1], 45
    jne .operand
    cmp byte [rax + 2], 0
    jne .operand
    add rbx, 8
    dec r12
    jnz .operand
.implicit:
    lea r13, [rel program]
    jmp .standard_input
.operand:
    mov r13, [rbx]
    add rbx, 8
    dec r12
    cmp byte [r13], 45
    jne .open
    cmp byte [r13 + 1], 0
    je .standard_input
.open:
    mov rdi, r13
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .input_error
    mov r14, rax
    jmp .copy
.standard_input:
    mov r14, [rel stdin]
.copy:
    lea rdi, [rel buffer]
    mov esi, 1
    mov edx, 4096
    mov rcx, r14
    call fread
    test rax, rax
    jz .check_input
    mov [rsp], rax
    lea rdi, [rel buffer]
    mov esi, 1
    mov rdx, rax
    mov rcx, [rel stdout]
    call fwrite
    cmp rax, [rsp]
    je .copy
    lea rdi, [rel program]
    call perror
    mov r15d, 1
    xor r12d, r12d               ; stop after an output error
    jmp .close
.check_input:
    mov rdi, r14
    call ferror
    test eax, eax
    jz .close
    mov rdi, r13
    call perror
    mov r15d, 1
.close:
    cmp r14, [rel stdin]
    je .next_operand
    mov rdi, r14
    call fclose
    test eax, eax
    jz .next_operand
.input_error:
    mov rdi, r13
    call perror
    mov r15d, 1
.next_operand:
    test r12, r12
    jnz .operand
    mov rdi, [rel stdout]
    call fflush
    test eax, eax
    jz .done
    lea rdi, [rel program]
    call perror
    mov r15d, 1
.done:
    mov eax, r15d
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.cat alloc noexec nowrite progbits
program:
    db "cat", 0
read_mode:
    db "rb", 0

section .bss.cat alloc noexec write nobits align=16
buffer:
    resb 4096

section .note.GNU-stack noalloc noexec nowrite progbits
