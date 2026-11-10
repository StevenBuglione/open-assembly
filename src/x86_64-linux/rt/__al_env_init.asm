; Original environment bootstrap. rdi points to the initial envp vector.
bits 64
default rel

global __al_env_init:function
global environ:data
global __al_env_lock:data
extern __al_map_anon:function
extern __al_panic:function

section .text.__al_env_init alloc exec nowrite progbits
__al_env_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    xor r12d, r12d
.count:
    cmp qword [rbx + r12*8], 0
    je .counted
    inc r12
    jmp .count
.counted:
    test r12, r12
    jz .empty
    lea rdi, [r12*8 + 8]           ; include the terminator
    call __al_map_anon
    test rax, rax
    jz .fail
    xor ecx, ecx
.copy:
    mov rdx, [rbx + rcx*8]
    mov [rax + rcx*8], rdx
    inc rcx
    test rdx, rdx
    jnz .copy
    jmp .publish
.empty:
    lea rax, [rel empty_vector]
.publish:
    mov [rel environ], rax
    pop r12
    pop rbx
    pop rbp
    ret
.fail:
    lea rdi, [rel failure]
    mov esi, 45
    call __al_panic
    ud2

section .rodata.__al_env_init alloc noexec nowrite progbits
failure:
    db "open-assembly: cannot initialize environment", 10

section .bss.__al_env_init alloc noexec write nobits align=8
environ:
    resq 1
empty_vector:
    resq 1
__al_env_lock:
    resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
