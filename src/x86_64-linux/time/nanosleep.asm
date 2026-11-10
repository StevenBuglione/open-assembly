; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nanosleep
; header: time.h
; prototype: int nanosleep(const struct timespec *request, struct timespec *remaining)
; standard: POSIX.1-2024 XSH nanosleep
; deps: __errno_location
; errno: EFAULT, EINTR, EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-time64
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Suspend execution for the specified relative interval using Linux time64 fields.
; semantics: An interrupting handler causes a return of -1 with EINTR and a remaining interval when requested.
; semantics: Return zero and preserve errno on success. Report other kernel errors without restarting.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global nanosleep:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.nanosleep alloc exec nowrite progbits
nanosleep:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    mov edi, 35                  ; __NR_nanosleep
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
