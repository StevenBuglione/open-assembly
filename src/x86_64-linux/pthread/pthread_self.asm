; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_self
; header: pthread.h
; prototype: pthread_t pthread_self(void)
; standard: POSIX.1-2024 XSH pthread_self
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-lifecycle
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the current thread's opaque handle, including for the initial thread.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_self:function

section .text.pthread_self alloc exec nowrite progbits
pthread_self:
    mov rax, [fs:0]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
