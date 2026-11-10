; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_equal
; header: pthread.h
; prototype: int pthread_equal(pthread_t left, pthread_t right)
; standard: POSIX.1-2024 XSH pthread_equal
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-lifecycle
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return nonzero if the two valid handles identify the same thread. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_equal:function

section .text.pthread_equal alloc exec nowrite progbits
pthread_equal:
    xor eax, eax
    cmp rdi, rsi
    jne .done
    mov eax, 1
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
