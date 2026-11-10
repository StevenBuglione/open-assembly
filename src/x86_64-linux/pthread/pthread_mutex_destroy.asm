; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutex_destroy
; header: pthread.h
; prototype: int pthread_mutex_destroy(pthread_mutex_t *mutex)
; standard: POSIX.1-2024 XSH pthread_mutex_destroy
; deps: -
; errno: EBUSY, EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Invalidate an initialized unlocked mutex. Diagnose an owned mutex with EBUSY.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutex_destroy:function

section .text.pthread_mutex_destroy alloc exec nowrite progbits
pthread_mutex_destroy:
    test rdi, rdi
    jz .invalid
    cmp qword [rdi + 24], 0
    jne .invalid
    cmp dword [rdi], 0
    jne .busy
    mov qword [rdi + 24], -1
    xor eax, eax
    ret
.busy:
    mov eax, 16
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
