; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: clock_getres
; header: time.h
; prototype: int clock_getres(clockid_t clock_id, struct timespec *res)
; standard: POSIX.1-2024 XSH clock_getres
; deps: __errno_location
; errno: EFAULT, EINVAL, ENODEV, ENOTSUP
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-time64
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Read the selected clock resolution. A null res validates the clock without storing a result.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on kernel failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global clock_getres:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.clock_getres alloc exec nowrite progbits
clock_getres:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rdx, rsi
    movsxd rsi, edi
    xor ecx, ecx
    xor r8d, r8d
    mov edi, 229                 ; __NR_clock_getres
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
