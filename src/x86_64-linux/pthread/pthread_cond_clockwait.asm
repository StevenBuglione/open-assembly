; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_cond_clockwait
; header: pthread.h
; prototype: int pthread_cond_clockwait(pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex, clockid_t clock_id, const struct timespec *restrict abstime)
; standard: POSIX.1-2024 XSH pthread_cond_clockwait
; deps: pthread_mutex_lock, pthread_mutex_unlock, __errno_location
; errno: EAGAIN, EINVAL, EPERM, ETIMEDOUT
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Wait using an explicit realtime or monotonic absolute deadline, then reacquire the singly held mutex.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_cond_clockwait:function
extern __al_cond_wait:function

section .text.pthread_cond_clockwait alloc exec nowrite progbits
pthread_cond_clockwait:
    movsxd rax, edx
    cmp rax, 1
    ja .invalid
    test rcx, rcx
    jz .invalid
    mov rdx, rcx
    mov rcx, rax
    sub rsp, 8
    call __al_cond_wait
    add rsp, 8
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
