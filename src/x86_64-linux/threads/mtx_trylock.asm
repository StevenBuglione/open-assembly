; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mtx_trylock
; header: threads.h
; prototype: int mtx_trylock(mtx_t *mutex)
; standard: C17 7.26.4.5
; deps: pthread_mutex_trylock
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Attempt acquisition without waiting. Report thrd_busy for a held nonrecursive mutex.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mtx_trylock:function
extern pthread_mutex_trylock:function

section .text.mtx_trylock alloc exec nowrite progbits
mtx_trylock:
    sub rsp, 8
    call pthread_mutex_trylock
    add rsp, 8
    test eax, eax
    jz .done
    cmp eax, 16
    je .specific
    mov eax, 2                   ; thrd_error
    ret
.specific:
    mov eax, 1                   ; thrd_busy
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
