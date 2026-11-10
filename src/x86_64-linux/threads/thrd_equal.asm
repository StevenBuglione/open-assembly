; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_equal
; header: threads.h
; prototype: int thrd_equal(thrd_t left, thrd_t right)
; standard: C17 7.26.5.4
; deps: pthread_equal
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare two thread identifiers.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_equal:function
extern pthread_equal:function

section .text.thrd_equal alloc exec nowrite progbits
thrd_equal:
    sub rsp, 8
    call pthread_equal
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
