; Append a literal name and slash count to the mutable traversal path.
; RDI context, RSI name or null, RDX slash count. Return zero or GLOB_NOSPACE.
bits 64
default rel

global __al_glob_path:function
extern __errno_location:function
extern strlen:function
extern realloc:function
extern memcpy:function
extern memset:function

section .text.__al_glob_path alloc exec nowrite progbits
__al_glob_path:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor r14d, r14d
    test r12, r12
    jz .length
    mov rdi, r12
    call strlen
    mov r14, rax
.length:
    mov r15, [rbx + 88]
    add r15, r14
    jc .overflow
    add r15, r13
    jc .overflow
    mov rsi, r15
    add rsi, 1
    jc .overflow
    cmp rsi, [rbx + 96]
    jbe .copy
    mov rax, [rbx + 96]
    add rax, rax
    jc .allocate
    cmp rax, 64
    jae .test_growth
    mov eax, 64
.test_growth:
    cmp rax, rsi
    jb .allocate
    mov rsi, rax
.allocate:
    mov [rsp], rsi
    mov rdi, [rbx + 80]
    call realloc
    test rax, rax
    jz .no_space
    mov [rbx + 80], rax
    mov rax, [rsp]
    mov [rbx + 96], rax
.copy:
    test r14, r14
    jz .slashes
    mov rdi, [rbx + 80]
    add rdi, [rbx + 88]
    mov rsi, r12
    mov rdx, r14
    call memcpy
.slashes:
    test r13, r13
    jz .terminate
    mov rdi, [rbx + 80]
    add rdi, [rbx + 88]
    add rdi, r14
    mov esi, 47
    mov rdx, r13
    call memset
.terminate:
    mov rax, [rbx + 80]
    mov byte [rax + r15], 0
    mov [rbx + 88], r15
    xor eax, eax
    jmp .return
.overflow:
    call __errno_location
    mov dword [rax], 12         ; ENOMEM
.no_space:
    mov eax, 1                 ; GLOB_NOSPACE
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
