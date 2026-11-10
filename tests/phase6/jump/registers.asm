; Independent x86-64 System V snapshot and resume probe for the public jmp_buf.
bits 64
default rel

global main:function
extern setjmp:function
extern longjmp:function

section .rodata
align 8
expected:
    dq 0x13b71e26c09d5331
    dq 0xbb729b0f9517c115
    dq 0x809de66d5cbbaa23
    dq 0xad2eef05637ca005
    dq 0xe677ea4af9b8d62a
    dq 0x0eb41fe49619c832

section .bss
align 8
context: resq 8
saved_rsp: resq 1

section .text
main:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov [rel saved_rsp], rsp
    mov rbx, [rel expected]
    mov rbp, [rel expected + 8]
    mov r12, [rel expected + 16]
    mov r13, [rel expected + 24]
    mov r14, [rel expected + 32]
    mov r15, [rel expected + 40]
    lea rdi, [rel context]
    call setjmp

.resume:
    cmp rsp, [rel saved_rsp]
    jne .bad_stack
    test eax, eax
    jnz .restored

    lea rsi, [rel expected]
    lea rdi, [rel context]
    xor ecx, ecx
.compare_saved:
    mov rax, [rsi + rcx * 8]
    cmp [rdi + rcx * 8], rax
    jne .bad_snapshot
    inc ecx
    cmp ecx, 6
    jne .compare_saved
    cmp [rdi + 48], rsp
    jne .bad_snapshot
    lea rax, [rel .resume]
    cmp [rdi + 56], rax
    jne .bad_snapshot

    xor ebx, ebx
    xor ebp, ebp
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
    sub rsp, 32
    mov esi, -7
    call longjmp
    ud2

.restored:
    cmp eax, -7
    jne .bad_restore
    cmp rbx, [rel expected]
    jne .bad_restore
    cmp rbp, [rel expected + 8]
    jne .bad_restore
    cmp r12, [rel expected + 16]
    jne .bad_restore
    cmp r13, [rel expected + 24]
    jne .bad_restore
    cmp r14, [rel expected + 32]
    jne .bad_restore
    cmp r15, [rel expected + 40]
    jne .bad_restore
    xor eax, eax
    jmp .finish

.bad_stack:
    mov rsp, [rel saved_rsp]
    mov eax, 51
    jmp .finish
.bad_snapshot:
    mov eax, 52
    jmp .finish
.bad_restore:
    mov eax, 53
.finish:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
