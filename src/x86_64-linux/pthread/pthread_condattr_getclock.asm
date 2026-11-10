; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_condattr_getclock
; header: pthread.h
; prototype: int pthread_condattr_getclock(const pthread_condattr_t *restrict attr, clockid_t *restrict clock_id)
; standard: POSIX.1-2024 XSH pthread_condattr_getclock
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the selected absolute deadline clock.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_condattr_getclock:function

section .text.pthread_condattr_getclock alloc exec nowrite progbits
pthread_condattr_getclock:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f414341
    jne .invalid
    test rsi, rsi
    jz .invalid
    mov eax, [rdi + 4]
    mov [rsi], eax
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
