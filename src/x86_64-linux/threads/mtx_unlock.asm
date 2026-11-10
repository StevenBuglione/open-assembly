; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mtx_unlock
; header: threads.h
; prototype: int mtx_unlock(mtx_t *mutex)
; standard: C17 7.26.4.6
; deps: pthread_mutex_unlock
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release one level of mutex ownership.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mtx_unlock:function
extern pthread_mutex_unlock:function

section .text.mtx_unlock alloc exec nowrite progbits
mtx_unlock:
    sub rsp, 8
    call pthread_mutex_unlock
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
