; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: thrd_join
; header: threads.h
; prototype: int thrd_join(thrd_t thread, int *result)
; standard: C17 7.26.5.6
; deps: pthread_self
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-threads
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Join and reclaim the thread. On success, store its int result only if requested.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global thrd_join:function
extern __al_thread_join:function

section .text.thrd_join alloc exec nowrite progbits
thrd_join:
    push rbx
    mov rbx, rsi
    call __al_thread_join
    test eax, eax
    jnz .error
    test rbx, rbx
    jz .done
    mov [rbx], edx               ; the result object is an int
.done:
    pop rbx
    ret
.error:
    mov eax, 2                   ; thrd_error
    jmp .done

section .note.GNU-stack noalloc noexec nowrite progbits
