; Original descriptor limit query. rdi = signed descriptor, rax = positive error or zero.
bits 64
default rel

global __al_spawn_check_fd:function
extern __al_syscall:function

section .text.__al_spawn_check_fd alloc exec nowrite progbits
__al_spawn_check_fd:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 24
    mov rbx, rdi
    test rbx, rbx
    js .invalid
    mov qword [rsp], 0
    mov esi, 7                    ; RLIMIT_NOFILE
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 97                   ; __NR_getrlimit
    lea rdx, [rsp + 8]
    call __al_syscall
    cmp rax, -4095
    jae .kernel_error
    cmp rbx, [rsp + 8]           ; soft descriptor limit
    jae .invalid
    jmp .done
.kernel_error:
    neg eax
    jmp .done
.invalid:
    mov eax, 9                    ; EBADF
.done:
    add rsp, 24
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
