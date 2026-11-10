; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: call_once
; header: threads.h
; prototype: void call_once(once_flag *flag, void (*initialize)(void))
; standard: C17 7.26.2.1
; deps: pthread_once
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Complete the selected initializer once and publish its effects to every caller.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global call_once:function
extern pthread_once:function

section .text.call_once alloc exec nowrite progbits
call_once:
    sub rsp, 8
    call pthread_once
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
