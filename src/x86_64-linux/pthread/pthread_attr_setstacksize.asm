; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_attr_setstacksize
; header: pthread.h
; prototype: int pthread_attr_setstacksize(pthread_attr_t *attr, size_t stacksize)
; standard: POSIX.1-2024 XSH pthread_attr_setstacksize
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-attributes
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Store the minimum writable stack size. Reject values below PTHREAD_STACK_MIN without changing the object.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_attr_setstacksize:function

section .text.pthread_attr_setstacksize alloc exec nowrite progbits
pthread_attr_setstacksize:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f415448
    jne .invalid
    cmp rsi, 16384
    jb .invalid
    mov [rdi + 8], rsi
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
