; Original stack allocator. Inputs: requested usable bytes and guard bytes.
; Return mapping base/length in RAX/RDX, or null on failure.
bits 64
default rel

global __al_thread_stack_new:function
extern __al_tls_template:data
extern __al_syscall:function
extern __al_unmap_anon:function

section .text.__al_thread_stack_new alloc exec nowrite progbits
__al_thread_stack_new:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov qword [rsp], 0
    mov r12, [rel __al_tls_template + 48]
    mov rax, r12
    neg rax
    lea rcx, [r12 - 1]
    mov r15, rdi
    add r15, rcx
    jc .failure
    and r15, rax                 ; usable bytes rounded to a page
    mov r14, rsi
    add r14, rcx
    jc .failure
    and r14, rax                 ; guard bytes rounded to a page
    mov r13, r15
    add r13, r14
    jc .failure

    mov edi, 9                    ; __NR_mmap
    xor esi, esi
    mov rdx, r13
    mov ecx, 3
    test r14, r14
    jz .map
    xor ecx, ecx                  ; PROT_NONE until the guard is established
.map:
    mov r8d, 34                   ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r9, -1
    call __al_syscall
    cmp rax, -4095
    jae .failure
    mov rbx, rax
    test r14, r14
    jz .success
    mov edi, 10                   ; __NR_mprotect
    lea rsi, [rbx + r14]
    mov rdx, r15
    mov ecx, 3                    ; PROT_READ | PROT_WRITE
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .unmap
.success:
    mov rax, rbx
    mov rdx, r13
    jmp .done
.unmap:
    mov rdi, rbx
    mov rsi, r13
    call __al_unmap_anon
.failure:
    xor eax, eax
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
