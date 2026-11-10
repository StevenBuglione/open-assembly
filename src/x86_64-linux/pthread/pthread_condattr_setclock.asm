; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_condattr_setclock
; header: pthread.h
; prototype: int pthread_condattr_setclock(pthread_condattr_t *attr, clockid_t clock_id)
; standard: POSIX.1-2024 XSH pthread_condattr_setclock
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Select CLOCK_REALTIME or CLOCK_MONOTONIC for absolute deadlines.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_condattr_setclock:function

section .text.pthread_condattr_setclock alloc exec nowrite progbits
pthread_condattr_setclock:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f414341
    jne .invalid
    movsxd rsi, esi
    cmp rsi, 1
    ja .invalid
    mov [rdi + 4], esi
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
