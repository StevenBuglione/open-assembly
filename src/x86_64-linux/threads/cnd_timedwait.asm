; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cnd_timedwait
; header: threads.h
; prototype: int cnd_timedwait(cnd_t *restrict cond, mtx_t *restrict mutex, const struct timespec *restrict deadline)
; standard: C17 7.26.3.5
; deps: pthread_cond_timedwait
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release the mutex while waiting until the absolute TIME_UTC deadline. Reacquire it before return.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cnd_timedwait:function
extern pthread_cond_timedwait:function

section .text.cnd_timedwait alloc exec nowrite progbits
cnd_timedwait:
    sub rsp, 8
    call pthread_cond_timedwait
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
