; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cnd_broadcast
; header: threads.h
; prototype: int cnd_broadcast(cnd_t *cond)
; standard: C17 7.26.3.1
; deps: pthread_cond_broadcast
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Unblock all current waiters and return a C thread status.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cnd_broadcast:function
extern pthread_cond_broadcast:function

section .text.cnd_broadcast alloc exec nowrite progbits
cnd_broadcast:
    sub rsp, 8
    call pthread_cond_broadcast
    add rsp, 8
    test eax, eax
    jz .done
    mov eax, 2                   ; thrd_error
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
