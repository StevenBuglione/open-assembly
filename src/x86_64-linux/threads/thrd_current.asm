; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_current
; header: threads.h
; prototype: thrd_t thrd_current(void)
; standard: C17 7.26.5.2
; deps: pthread_self
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the calling thread identifier.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_current:function
extern pthread_self:function

section .text.thrd_current alloc exec nowrite progbits
thrd_current:
    sub rsp, 8
    call pthread_self
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
