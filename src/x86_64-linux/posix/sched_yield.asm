; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sched_yield
; header: sched.h
; prototype: int sched_yield(void)
; standard: POSIX.1-2024 XSH sched_yield
; deps: __errno_location
; errno: ENOSYS, EPERM
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-scheduling
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Request a yield of the calling thread through Linux sched_yield.
; semantics: Return zero and preserve errno on success. Translate a failed syscall to -1 with errno.
; semantics: The Linux scheduler selects any subsequent runnable thread.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sched_yield:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.sched_yield alloc exec nowrite progbits
sched_yield:
    sub rsp, 8
    mov qword [rsp], 0
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 24                  ; __NR_sched_yield
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
