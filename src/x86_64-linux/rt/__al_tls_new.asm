; Original static variant-II TLS allocator. Return FS base or null.
bits 64
default rel

global __al_tls_new:function
extern __al_tls_template:data
extern __al_syscall:function
extern __al_panic:function

section .text.__al_tls_new alloc exec nowrite progbits
__al_tls_new:
    push rbx
    push r12
    sub rsp, 8
    mov qword [rsp], 0
    lea rbx, [rel __al_tls_template]
    mov rdx, [rbx + 24]
    dec rdx
    add rdx, [rbx + 16]
    jc .failure
    add rdx, 2336                  ; descriptor size beyond the thread pointer
    jc .failure
    mov r12, rdx
    mov edi, 9                    ; __NR_mmap
    xor esi, esi
    mov ecx, 3                    ; PROT_READ | PROT_WRITE
    mov r8d, 34                   ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r9, -1
    call __al_syscall
    cmp rax, -4095
    jae .failure

    mov rdx, [rbx + 24]
    lea rcx, [rdx - 1]
    mov r10, rax                  ; mapping base retained for reclamation
    add rax, [rbx + 16]
    add rax, rcx
    neg rdx
    and rax, rdx
    mov [rax], rax
    mov [rax + 0x10], rax
    mov edx, 1
    lock xadd qword [rel next_owner_token], rdx
    test rdx, rdx
    jz .token_exhausted
    mov [rax + 0x48], rdx
    mov rdx, [rbx + 32]
    mov [rax + 0x28], rdx
    mov rdx, [rbx + 40]
    mov [rax + 0x30], rdx
    mov [rax + 0x50], r10
    mov [rax + 0x58], r12

    mov rdi, rax
    sub rdi, [rbx + 16]
    mov rsi, [rbx]
    mov rcx, [rbx + 8]
    test rcx, rcx
    jz .done
.copy:
    mov dl, [rsi]
    mov [rdi], dl
    inc rsi
    inc rdi
    dec rcx
    jnz .copy
    jmp .done
.failure:
    xor eax, eax
.done:
    add rsp, 8
    pop r12
    pop rbx
    ret

.token_exhausted:
    lea rdi, [rel token_error]
    mov esi, 43
    call __al_panic
    ud2

section .rodata.__al_tls_new alloc noexec nowrite progbits
token_error: db "open-assembly: thread owner token overflow", 10

section .data.__al_tls_new alloc noexec write progbits align=8
next_owner_token: dq 1

section .note.GNU-stack noalloc noexec nowrite progbits
