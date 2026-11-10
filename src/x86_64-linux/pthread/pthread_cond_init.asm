; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_cond_init
; header: pthread.h
; prototype: int pthread_cond_init(pthread_cond_t *restrict cond, const pthread_condattr_t *restrict attr)
; standard: POSIX.1-2024 XSH pthread_cond_init
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize an empty process-private condition queue with the selected clock.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_cond_init:function

section .text.pthread_cond_init alloc exec nowrite progbits
pthread_cond_init:
    test rdi, rdi
    jz .invalid
    xor eax, eax
    test rsi, rsi
    jz .initialize
    cmp dword [rsi], 0x4f414341
    jne .invalid
    mov eax, [rsi + 4]
    cmp eax, 1
    ja .invalid
.initialize:
    mov dword [rdi], 0
    mov [rdi + 4], eax
    mov qword [rdi + 8], 0
    mov qword [rdi + 16], 0
    mov qword [rdi + 24], 0
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
