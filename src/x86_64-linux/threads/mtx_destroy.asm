; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mtx_destroy
; header: threads.h
; prototype: void mtx_destroy(mtx_t *mutex)
; standard: C17 7.26.4.1
; deps: pthread_mutex_destroy
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Destroy an unlocked initialized mutex with no waiters.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mtx_destroy:function
extern pthread_mutex_destroy:function

section .text.mtx_destroy alloc exec nowrite progbits
mtx_destroy:
    sub rsp, 8
    call pthread_mutex_destroy
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
