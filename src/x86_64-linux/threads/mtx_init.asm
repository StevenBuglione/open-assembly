; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mtx_init
; header: threads.h
; prototype: int mtx_init(mtx_t *mutex, int type)
; standard: C17 7.26.4.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Initialize a plain or recursive process-private mutex with the specified C thread type.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mtx_init:function
extern __al_mutex_init:function

section .text.mtx_init alloc exec nowrite progbits
mtx_init:
    movsxd rsi, esi
    cmp esi, 3                   ; mtx_timed | mtx_recursive
    ja .error
    and esi, 1                   ; the timing bit is a C11 caller precondition
    shl esi, 1                   ; PTHREAD_MUTEX_NORMAL or PTHREAD_MUTEX_RECURSIVE
    sub rsp, 8
    call __al_mutex_init
    add rsp, 8
    test eax, eax
    jnz .error
    ret
.error:
    mov eax, 2                   ; thrd_error
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
