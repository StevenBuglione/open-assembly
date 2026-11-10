; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cnd_destroy
; header: threads.h
; prototype: void cnd_destroy(cnd_t *cond)
; standard: C17 7.26.3.2
; deps: pthread_cond_destroy
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Destroy an initialized condition with no waiters.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cnd_destroy:function
extern pthread_cond_destroy:function

section .text.cnd_destroy alloc exec nowrite progbits
cnd_destroy:
    sub rsp, 8
    call pthread_cond_destroy
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
