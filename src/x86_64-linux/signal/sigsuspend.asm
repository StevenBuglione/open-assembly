; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigsuspend
; header: signal.h
; prototype: int sigsuspend(const sigset_t *mask)
; standard: POSIX.1-2024 XSH sigsuspend
; deps: __errno_location
; errno: EFAULT, EINTR, EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Temporarily replace the calling thread signal mask and suspend until a signal terminates or interrupts the call.
; semantics: After an interrupting handler, restore the original mask and return -1 with EINTR.
; semantics: Translate any other Linux error without retrying the operation.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigsuspend:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.sigsuspend alloc exec nowrite progbits
sigsuspend:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rsi, rdi
    mov edi, 130                  ; __NR_rt_sigsuspend
    mov edx, 8
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
