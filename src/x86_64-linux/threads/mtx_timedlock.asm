; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mtx_timedlock
; header: threads.h
; prototype: int mtx_timedlock(mtx_t *restrict mutex, const struct timespec *restrict deadline)
; standard: C17 7.26.4.4
; deps: pthread_mutex_timedlock
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Acquire the mutex until the absolute TIME_UTC deadline and report thrd_timedout on expiration.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mtx_timedlock:function
extern pthread_mutex_timedlock:function

section .text.mtx_timedlock alloc exec nowrite progbits
mtx_timedlock:
    sub rsp, 8
    call pthread_mutex_timedlock
    add rsp, 8
    test eax, eax
    jz .done
    cmp eax, 110
    je .specific
    mov eax, 2                   ; thrd_error
    ret
.specific:
    mov eax, 4                   ; thrd_timedout
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
