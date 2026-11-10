; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_join
; header: pthread.h
; prototype: int pthread_join(pthread_t thread, void **result)
; standard: POSIX.1-2024 XSH pthread_join
; deps: pthread_self
; errno: EDEADLK, EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-lifecycle
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Wait for a valid joinable target to terminate, then reclaim its runtime storage.
; semantics: If result is nonnull, publish the target pointer result only after termination.
; semantics: Reject self-join with EDEADLK. Retry signal interruption internally and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_join:function
extern __al_thread_join:function

section .text.pthread_join alloc exec nowrite progbits
pthread_join:
    push rbx
    mov rbx, rsi
    call __al_thread_join
    test eax, eax
    jnz .done
    test rbx, rbx
    jz .done
    mov [rbx], rdx
.done:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
