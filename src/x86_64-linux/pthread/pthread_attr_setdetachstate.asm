; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_attr_setdetachstate
; header: pthread.h
; prototype: int pthread_attr_setdetachstate(pthread_attr_t *attr, int detachstate)
; standard: POSIX.1-2024 XSH pthread_attr_setdetachstate
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-attributes
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Set the joinable or detached creation state. Reject other values without changing the object.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_attr_setdetachstate:function

section .text.pthread_attr_setdetachstate alloc exec nowrite progbits
pthread_attr_setdetachstate:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f415448
    jne .invalid
    movsxd rsi, esi
    cmp rsi, 1
    ja .invalid
    mov [rdi + 24], esi
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
