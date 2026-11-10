; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: gettimeofday
; header: sys/time.h
; prototype: int gettimeofday(struct timeval *restrict value, void *restrict zone)
; standard: Extension ABI gettimeofday
; deps: __errno_location
; errno: EFAULT
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Obtain wall time in signed seconds and microseconds using the historical Linux time ABI.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global gettimeofday:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.gettimeofday alloc exec nowrite progbits
gettimeofday:
    sub rsp, 8
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 96                  ; __NR_gettimeofday
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
