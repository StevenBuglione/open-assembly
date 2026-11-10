; Original standard stream bootstrap. See the Phase 4 stream ABI.
bits 64
default rel

global __al_stdio_init:function
global stdin:data
global stdout:data
global stderr:data
global __al_stdio_lock:data
global __al_streams:data
extern __al_stdio_isatty:function

section .text.__al_stdio_init alloc exec nowrite progbits
__al_stdio_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    lea rbx, [rel standard_files]
    lea r12, [rbx + 4224]
    lea rcx, [r12 + 4224]
    mov [rel stdin], rbx
    mov [rel stdout], r12
    mov [rel stderr], rcx
    mov [rel __al_streams], rbx

    ; descriptor, flags, registry link, buffer, capacity, pushback
    mov qword [rbx + 8], 1
    mov [rbx + 16], r12
    lea rax, [rbx + 128]
    mov [rbx + 24], rax
    mov qword [rbx + 32], 4096
    mov qword [rbx + 72], -1

    mov qword [r12], 1
    mov qword [r12 + 8], 2
    mov [r12 + 16], rcx
    lea rax, [r12 + 128]
    mov [r12 + 24], rax
    mov qword [r12 + 32], 4096
    mov qword [r12 + 72], -1

    mov qword [rcx], 2
    mov qword [rcx + 8], 2
    mov qword [rcx + 64], 2
    mov qword [rcx + 72], -1

    xor edi, edi
    call __al_stdio_isatty
    test rax, rax
    jnz .stdout
    mov qword [rbx + 64], 1
.stdout:
    mov edi, 1
    call __al_stdio_isatty
    test rax, rax
    jnz .done
    mov qword [r12 + 64], 1
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .bss.__al_stdio_init alloc noexec write nobits align=16
stdin:
    resq 1
stdout:
    resq 1
stderr:
    resq 1
__al_streams:
    resq 1
__al_stdio_lock:
    resq 1
standard_files:
    resb 12672

section .note.GNU-stack noalloc noexec nowrite progbits
