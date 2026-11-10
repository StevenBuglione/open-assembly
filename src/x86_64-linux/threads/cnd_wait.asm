; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cnd_wait
; header: threads.h
; prototype: int cnd_wait(cnd_t *cond, mtx_t *mutex)
; standard: C17 7.26.3.6
; deps: pthread_cond_wait
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release the mutex while waiting and reacquire it before return.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cnd_wait:function
extern pthread_cond_wait:function

section .text.cnd_wait alloc exec nowrite progbits
cnd_wait:
    sub rsp, 8
    call pthread_cond_wait
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
