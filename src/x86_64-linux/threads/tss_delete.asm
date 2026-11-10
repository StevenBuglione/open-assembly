; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tss_delete
; header: threads.h
; prototype: void tss_delete(tss_t key)
; standard: C17 7.26.6.2
; deps: pthread_key_delete
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Invalidate a key without running its destructors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tss_delete:function
extern pthread_key_delete:function

section .text.tss_delete alloc exec nowrite progbits
tss_delete:
    sub rsp, 8
    mov edi, edi
    call pthread_key_delete
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
