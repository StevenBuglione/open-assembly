; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_exit
; header: threads.h
; prototype: _Noreturn void thrd_exit(int result)
; standard: C17 7.26.5.5
; deps: pthread_exit
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: edi:s32
; variadic: false
; noreturn: true
; semantics: Terminate the calling thread and publish its signed int result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_exit:function
extern pthread_exit:function

section .text.thrd_exit alloc exec nowrite progbits
thrd_exit:
    sub rsp, 8
    movsxd rdi, edi
    call pthread_exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
