; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tss_get
; header: threads.h
; prototype: void *tss_get(tss_t key)
; standard: C17 7.26.6.3
; deps: pthread_getspecific
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Return the current thread value for the live key, or null.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tss_get:function
extern pthread_getspecific:function

section .text.tss_get alloc exec nowrite progbits
tss_get:
    sub rsp, 8
    mov edi, edi
    call pthread_getspecific
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
