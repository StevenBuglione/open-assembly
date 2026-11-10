; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: kill
; header: signal.h
; prototype: int kill(pid_t pid, int sig)
; standard: POSIX.1-2024 XSH kill
; deps: __errno_location
; errno: EINVAL, EPERM, ESRCH
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Send the requested signal to the process or process group selected by Linux pid semantics.
; semantics: Signal zero performs Linux existence and permission checks without delivering a signal.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global kill:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.kill alloc exec nowrite progbits
kill:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rdx, esi
    movsxd rsi, edi
    mov edi, 62                   ; __NR_kill
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
