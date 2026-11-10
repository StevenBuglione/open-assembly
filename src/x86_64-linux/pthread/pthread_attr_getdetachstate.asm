; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_attr_getdetachstate
; header: pthread.h
; prototype: int pthread_attr_getdetachstate(const pthread_attr_t *attr, int *detachstate)
; standard: POSIX.1-2024 XSH pthread_attr_getdetachstate
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-attributes
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the initialized object's joinable or detached creation state.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_attr_getdetachstate:function

section .text.pthread_attr_getdetachstate alloc exec nowrite progbits
pthread_attr_getdetachstate:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f415448
    jne .invalid
    test rsi, rsi
    jz .invalid
    mov eax, [rdi + 24]
    mov [rsi], eax
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
