; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: system
; header: stdlib.h
; prototype: int system(const char *command)
; standard: C17 7.22.4.8
; deps: malloc, free, __errno_location, _exit
; errno: EAGAIN, ECHILD, EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-shell-process
; provenance: original
; narrow_args: -
; variadic: false
; semantics: For a null command, return a nonzero value when /bin/sh is executable and preserve errno.
; semantics: Execute a command with /bin/sh -c and wait for that specific child.
; semantics: While waiting, the parent ignores SIGINT and SIGQUIT and blocks SIGCHLD, then restores its state.
; semantics: The shell child inherits the original signal mask and disposition behavior.
; semantics: Return the raw wait status. Failed shell execution gives exit status 127 in the wait encoding.
; semantics: Return -1 with errno when the child cannot be created or its status cannot be collected.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global system:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __al_system_restore:function
extern __al_shell_exec:function
extern __al_shell_path:data
extern __al_lock:function
extern __al_unlock:function
extern malloc:function
extern free:function
extern _exit:function

section .text.system alloc exec nowrite progbits
system:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov qword [rsp], 0
    test rbx, rbx
    jnz .command
    mov edi, 21                   ; __NR_access
    lea rsi, [rel __al_shell_path]
    mov edx, 1                    ; X_OK
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .no_shell
    mov eax, 1
    jmp .done
.no_shell:
    xor eax, eax
    jmp .done
.command:
    mov edi, 88                   ; dispositions, masks, and wait status
    call malloc
    test rax, rax
    jz .allocation_failed
    mov r12, rax
    xor r13d, r13d                ; number of successful setup steps
    lea rdi, [rel system_lock]
    call __al_lock
    mov edi, 13                   ; __NR_rt_sigaction
    mov esi, 2                    ; SIGINT
    lea rdx, [rel ignored_action]
    mov rcx, r12
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .setup_failed
    mov r13d, 1
    mov edi, 13
    mov esi, 3                    ; SIGQUIT
    lea rdx, [rel ignored_action]
    lea rcx, [r12 + 32]
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .setup_failed
    mov r13d, 2
    mov qword [r12 + 72], 65536  ; SIGCHLD bit
    mov edi, 14                   ; __NR_rt_sigprocmask
    xor esi, esi                  ; SIG_BLOCK
    lea rdx, [r12 + 72]
    lea rcx, [r12 + 64]
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .setup_failed
    mov r13d, 3
    mov edi, 57                   ; __NR_fork
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .setup_failed
    test rax, rax
    jz .child
    mov r15, rax
.wait:
    mov edi, 61                   ; __NR_wait4
    mov rsi, r15
    lea rdx, [r12 + 80]
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4                   ; EINTR
    je .wait
    cmp rax, -4095
    jae .setup_failed
    mov r14d, [r12 + 80]
    jmp .restore
.setup_failed:
    mov r14, rax
.restore:
    mov rdi, r12
    mov rsi, r13
    call __al_system_restore
    cmp r14, -4095
    jae .release
    cmp rax, -4095
    jb .release
    mov r14, rax
.release:
    lea rdi, [rel system_lock]
    call __al_unlock
    mov rdi, r12
    call free
    cmp r14, -4095
    jae .error
    mov eax, r14d
    jmp .done
.error:
    mov rdi, r14
    call __al_syscall_result
    jmp .done
.allocation_failed:
    mov rax, -1
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.child:
    mov rdi, r12
    mov rsi, r13
    call __al_system_restore
    cmp rax, -4095
    jae .child_failed
    mov rdi, rbx
    call __al_shell_exec
    ud2
.child_failed:
    mov edi, 127
    call _exit
    ud2

section .rodata.system alloc noexec nowrite progbits align=8
ignored_action:
    dq 1, 0, 0, 0                 ; SIG_IGN

section .bss.system alloc noexec write nobits align=4
system_lock:
    resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
