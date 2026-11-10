; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_detach
; header: threads.h
; prototype: int thrd_detach(thrd_t thread)
; standard: C17 7.26.5.3
; deps: pthread_detach
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Detach the thread so the runtime reclaims it without a join.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_detach:function
extern pthread_detach:function

section .text.thrd_detach alloc exec nowrite progbits
thrd_detach:
    sub rsp, 8
    call pthread_detach
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
