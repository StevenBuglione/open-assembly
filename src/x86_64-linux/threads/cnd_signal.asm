; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cnd_signal
; header: threads.h
; prototype: int cnd_signal(cnd_t *cond)
; standard: C17 7.26.3.4
; deps: pthread_cond_signal
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Unblock one current waiter and return a C thread status.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cnd_signal:function
extern pthread_cond_signal:function

section .text.cnd_signal alloc exec nowrite progbits
cnd_signal:
    sub rsp, 8
    call pthread_cond_signal
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
