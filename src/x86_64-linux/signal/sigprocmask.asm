; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigprocmask
; header: signal.h
; prototype: int sigprocmask(int how, const sigset_t *restrict set, sigset_t *restrict oldset)
; standard: POSIX.1-2024 XSH sigprocmask
; deps: __errno_location
; errno: EFAULT, EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Apply SIG_BLOCK, SIG_UNBLOCK, or SIG_SETMASK to the calling thread when set is present.
; semantics: A null set queries the current mask regardless of how. Linux ignores attempts to block SIGKILL or SIGSTOP.
; semantics: Publish oldset only on success and clear its bytes above the low word.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigprocmask:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __al_sigset_publish:function

section .text.sigprocmask alloc exec nowrite progbits
sigprocmask:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 24
    mov rbx, rdx                  ; optional old mask
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    movsxd rsi, edi               ; how
    mov edi, 14                   ; __NR_rt_sigprocmask
    mov r8d, 8                    ; Linux kernel mask width
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .error
    test rbx, rbx
    jz .done
    mov rdi, rbx
    mov rsi, [rbx]
    call __al_sigset_publish
    jmp .done
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 24
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
