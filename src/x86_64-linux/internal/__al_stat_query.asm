; Original Linux stat layout translation. See docs/adr/0007-linux-files-process-signal-time.md.
; rdi = syscall number, rsi = fd, rdx = path, rcx = flags, r8 = public result.
bits 64
default rel

global __al_stat_query:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.__al_stat_query alloc exec nowrite progbits
__al_stat_query:
    push rbp
    mov rbp, rsp
    sub rsp, 176
    test r8, r8
    jz .bad_address
    mov [rsp + 160], r8
    mov qword [rsp], 0
    xor r9d, r9d
    cmp edi, 5                    ; __NR_fstat
    je .descriptor
    cmp edi, 262                  ; __NR_newfstatat
    jne .bad_number
    mov r8, rcx                   ; flags
    mov edi, 262
    lea rcx, [rsp + 8]            ; 144-byte kernel record
    call __al_syscall
    jmp .result
.descriptor:
    xor r8d, r8d
    xor ecx, ecx
    mov edi, 5
    lea rdx, [rsp + 8]            ; 144-byte kernel record
    call __al_syscall
.result:
    cmp rax, -4095
    jae .kernel_error
    mov rdx, [rsp + 160]
    movdqu xmm0, [rsp + 8]
    movdqu xmm1, [rsp + 24]
    movdqu xmm2, [rsp + 40]
    movdqu xmm3, [rsp + 56]
    movdqu xmm4, [rsp + 72]
    movdqu xmm5, [rsp + 88]
    movdqu xmm6, [rsp + 104]
    movdqu [rdx], xmm0
    movdqu [rdx + 16], xmm1
    movdqu [rdx + 32], xmm2
    movdqu [rdx + 48], xmm3
    movdqu [rdx + 64], xmm4
    movdqu [rdx + 80], xmm5
    movdqu [rdx + 96], xmm6
    mov rax, [rsp + 120]
    mov [rdx + 112], rax
    mov dword [rdx + 36], 0       ; public padding
    mov qword [rdx + 120], 0      ; public reserved words
    mov qword [rdx + 128], 0
    mov qword [rdx + 136], 0
    xor eax, eax
    jmp .done
.bad_address:
    mov rax, -14                  ; EFAULT
    jmp .kernel_error
.bad_number:
    mov rax, -22                  ; EINVAL
.kernel_error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 176
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
