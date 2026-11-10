; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_create
; header: threads.h
; prototype: int thrd_create(thrd_t *thread, thrd_start_t start, void *arg)
; standard: C17 7.26.5.1
; deps: pthread_exit, thrd_yield
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Create a thread with an independent stack and TLS, publish the handle, then run its int-returning routine.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_create:function
extern __al_thread_create:function

section .text.thrd_create alloc exec nowrite progbits
thrd_create:
    sub rsp, 8
    mov rcx, rdx
    mov rdx, rsi
    xor esi, esi                 ; default attributes
    mov r8d, 1                   ; signed int callback
    call __al_thread_create
    add rsp, 8
    test eax, eax
    jz .done
    cmp eax, 12                  ; ENOMEM
    je .nomem
    mov eax, 2                   ; thrd_error
    ret
.nomem:
    mov eax, 3                   ; thrd_nomem
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
