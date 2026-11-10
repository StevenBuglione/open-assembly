; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: clock_gettime
; header: time.h
; prototype: int clock_gettime(clockid_t clock_id, struct timespec *tp)
; standard: POSIX.1-2024 XSH clock_gettime
; deps: __errno_location
; errno: EFAULT, EINVAL, ENODEV, ENOTSUP
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-time64
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Read the selected Linux clock into the public 64-bit seconds and nanoseconds record.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on kernel failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global clock_gettime:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.clock_gettime alloc exec nowrite progbits
clock_gettime:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rdx, rsi
    movsxd rsi, edi
    xor ecx, ecx
    xor r8d, r8d
    mov edi, 228                 ; __NR_clock_gettime
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
