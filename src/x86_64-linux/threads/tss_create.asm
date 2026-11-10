; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tss_create
; header: threads.h
; prototype: int tss_create(tss_t *key, tss_dtor_t destructor)
; standard: C17 7.26.6.1
; deps: pthread_key_create
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Create a thread-specific key with an optional destructor and null initial values.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tss_create:function
extern pthread_key_create:function

section .text.tss_create alloc exec nowrite progbits
tss_create:
    sub rsp, 8
    call pthread_key_create
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
