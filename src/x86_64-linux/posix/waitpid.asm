; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: waitpid
; header: sys/wait.h
; prototype: pid_t waitpid(pid_t pid, int *wstatus, int options)
; standard: POSIX.1-2024 XSH waitpid
; deps: __errno_location
; errno: ECHILD, EFAULT, EINTR, EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: edi:s32, edx:s32
; variadic: false
; semantics: Wait for the matching child or process group according to Linux wait4 selection rules.
; semantics: Store the raw status only when a child status is available and wstatus is nonnull.
; semantics: A nonblocking call with no matching status returns zero and leaves wstatus unchanged.
; semantics: Preserve errno on success. Return -1 and set errno on failure, including EINTR without retry.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global waitpid:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.waitpid alloc exec nowrite progbits
waitpid:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rcx, edx
    mov rdx, rsi
    movsxd rsi, edi
    mov edi, 61                  ; __NR_wait4
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
