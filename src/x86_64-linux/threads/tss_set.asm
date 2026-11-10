; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tss_set
; header: threads.h
; prototype: int tss_set(tss_t key, void *value)
; standard: C17 7.26.6.4
; deps: pthread_setspecific
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Set the calling thread value for the live key and report a C thread status.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tss_set:function
extern pthread_setspecific:function

section .text.tss_set alloc exec nowrite progbits
tss_set:
    sub rsp, 8
    mov edi, edi
    call pthread_setspecific
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
