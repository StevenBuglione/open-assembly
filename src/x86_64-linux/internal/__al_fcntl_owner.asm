; Original signed owner query using Linux's typed result record.
bits 64
default rel

global __al_fcntl_owner:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.__al_fcntl_owner alloc exec nowrite progbits
__al_fcntl_owner:
    sub rsp, 24
    mov qword [rsp], 0
    mov rsi, rdi
    mov edi, 72                    ; __NR_fcntl
    mov edx, 16                    ; F_GETOWN_EX
    lea rcx, [rsp + 8]
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .kernel_error
    mov eax, [rsp + 12]
    cmp dword [rsp + 8], 2        ; F_OWNER_PGRP
    jne .done
    cmp eax, 1
    je .sentinel
    neg eax
.done:
    add rsp, 24
    ret

.sentinel:
    mov rdi, -75                   ; EOVERFLOW
    jmp .translate
.kernel_error:
    mov rdi, rax
.translate:
    call __al_syscall_result
    jmp .done

section .note.GNU-stack noalloc noexec nowrite progbits
