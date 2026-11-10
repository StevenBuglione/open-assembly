; Original lazy vDSO discovery. Return the callable address, or null.
bits 64
default rel

global __al_vdso_clock_entry:function
extern __al_auxv:data
extern __al_syscall:function
extern __al_vdso_lookup:function

section .text.__al_vdso_clock_entry alloc exec nowrite progbits
__al_vdso_clock_entry:
    mov rax, [rel cached_entry]
    test rax, rax
    jnz .known
    mov edx, 1
    lock cmpxchg qword [rel cached_entry], rdx
    jne .known

    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 96
    mov rbx, [rel __al_auxv]
    test rbx, rbx
    jz .unavailable
    mov ecx, 128
.auxv:
    mov rax, [rbx]
    test rax, rax               ; AT_NULL
    jz .unavailable
    cmp rax, 33                ; AT_SYSINFO_EHDR
    je .image
    add rbx, 16
    dec ecx
    jnz .auxv
    jmp .unavailable
.image:
    mov r12, [rbx + 8]
    test r12, r12
    jz .unavailable
    test r12d, 4095
    jnz .unavailable
    mov rax, r12
    add rax, 16384
    jc .unavailable

    mov qword [rsp], 0
    mov edi, 39                ; __NR_getpid
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jle .unavailable

    ; One destination vector and four page-sized source vectors.
    lea rdx, [rel image_copy]
    mov [rsp + 8], rdx
    mov qword [rsp + 16], 16384
    mov [rsp + 24], r12
    mov qword [rsp + 32], 4096
    lea rdx, [r12 + 4096]
    mov [rsp + 40], rdx
    mov qword [rsp + 48], 4096
    lea rdx, [r12 + 8192]
    mov [rsp + 56], rdx
    mov qword [rsp + 64], 4096
    lea rdx, [r12 + 12288]
    mov [rsp + 72], rdx
    mov qword [rsp + 80], 4096
    mov rsi, rax
    mov edi, 310               ; __NR_process_vm_readv
    lea rdx, [rsp + 8]
    mov ecx, 1
    lea r8, [rsp + 24]
    mov r9d, 4
    call __al_syscall
    test rax, rax
    jle .unavailable
    lea rdi, [rel image_copy]
    mov rsi, rax
    call __al_vdso_lookup
    test rax, rax
    jz .unavailable
    add rax, r12
    mov [rel cached_entry], rax
    jmp .done
.unavailable:
    xor eax, eax
.done:
    add rsp, 96
    pop r12
    pop rbx
    pop rbp
    ret
.known:
    cmp rax, 1                 ; initialization in progress or unavailable
    jne .ready
    xor eax, eax
.ready:
    ret

section .bss.__al_vdso_clock_entry alloc noexec write nobits align=16
cached_entry: resq 1
image_copy: resb 16384

section .note.GNU-stack noalloc noexec nowrite progbits
