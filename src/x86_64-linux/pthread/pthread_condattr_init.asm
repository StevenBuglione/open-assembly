; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_condattr_init
; header: pthread.h
; prototype: int pthread_condattr_init(pthread_condattr_t *attr)
; standard: POSIX.1-2024 XSH pthread_condattr_init
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize process-private condition attributes using CLOCK_REALTIME.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_condattr_init:function

section .text.pthread_condattr_init alloc exec nowrite progbits
pthread_condattr_init:
    test rdi, rdi
    jz .invalid
    mov qword [rdi], 0x4f414341
    mov qword [rdi + 8], 0
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
