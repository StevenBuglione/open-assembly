; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: clock_nanosleep
; header: time.h
; prototype: int clock_nanosleep(clockid_t clock_id, int flags, const struct timespec *request, struct timespec *remaining)
; standard: POSIX.1-2024 XSH clock_nanosleep
; deps: -
; errno: EFAULT, EINTR, EINVAL, ENOTSUP
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-time64
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Use the selected Linux clock and a relative request or a TIMER_ABSTIME deadline.
; semantics: For an interrupted relative request, store the remaining interval when requested.
; semantics: An absolute request does not store a remaining interval.
; semantics: Return zero on success or a positive Linux error number on failure. Preserve errno in either case.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global clock_nanosleep:function
extern __al_syscall:function

section .text.clock_nanosleep alloc exec nowrite progbits
clock_nanosleep:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov r8, rcx
    mov rcx, rdx
    movsxd rdx, esi
    movsxd rsi, edi
    mov edi, 230                 ; __NR_clock_nanosleep
    xor r9d, r9d
    call __al_syscall
    neg eax
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
