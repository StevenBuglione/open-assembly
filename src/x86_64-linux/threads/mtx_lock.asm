; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mtx_lock
; header: threads.h
; prototype: int mtx_lock(mtx_t *mutex)
; standard: C17 7.26.4.3
; deps: pthread_mutex_lock
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Acquire the mutex and return a C thread status.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mtx_lock:function
extern pthread_mutex_lock:function

section .text.mtx_lock alloc exec nowrite progbits
mtx_lock:
    sub rsp, 8
    call pthread_mutex_lock
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
