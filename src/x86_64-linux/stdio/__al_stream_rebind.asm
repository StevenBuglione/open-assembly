; Original stream association. Inputs: FILE, fd, flags. The registry is
; locked. Existing callers retain ownership and snapshot pins across rebind.
bits 64
default rel

global __al_stream_rebind:function
extern __al_streams:data
extern memset:function

section .text.__al_stream_rebind alloc exec nowrite progbits
__al_stream_rebind:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor esi, esi
    mov edx, 96
    call memset
    mov [rbx], r12
    mov [rbx + 8], r13
    mov rax, [rel __al_streams]
    mov [rbx + 16], rax
    lea rax, [rbx + 128]
    mov [rbx + 24], rax
    mov qword [rbx + 32], 4096
    mov qword [rbx + 72], -1
    mov [rel __al_streams], rbx
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
