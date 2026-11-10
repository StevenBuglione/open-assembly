; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_detach
; header: pthread.h
; prototype: int pthread_detach(pthread_t thread)
; standard: POSIX.1-2024 XSH pthread_detach
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-lifecycle
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release the join claim on a valid joinable target.
; semantics: A running detached target reclaims its runtime storage at termination.
; semantics: For a target already exiting, claim and finish cleanup after kernel termination.
; semantics: Return zero or a positive error and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_detach:function
extern __al_thread_reap:function

section .text.pthread_detach alloc exec nowrite progbits
pthread_detach:
    xor eax, eax                  ; open
    mov edx, 3                    ; detached
    lock cmpxchg dword [rdi + 0x74], edx
    jz .success                   ; descriptor may be gone after publication
    cmp eax, 1                    ; exiting open
    jne .invalid
    mov edx, 2                    ; claimed
    lock cmpxchg dword [rdi + 0x74], edx
    jnz .invalid
    sub rsp, 8
    call __al_thread_reap
    add rsp, 8
.success:
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
