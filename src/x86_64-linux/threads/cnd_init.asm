; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cnd_init
; header: threads.h
; prototype: int cnd_init(cnd_t *cond)
; standard: C17 7.26.3.3
; deps: pthread_cond_init
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize a process-private condition using the TIME_UTC clock.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cnd_init:function
extern pthread_cond_init:function

section .text.cnd_init alloc exec nowrite progbits
cnd_init:
    sub rsp, 8
    xor esi, esi
    call pthread_cond_init
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
