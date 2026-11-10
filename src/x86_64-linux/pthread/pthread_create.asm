; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_create
; header: pthread.h
; prototype: int pthread_create(pthread_t *restrict thread, const pthread_attr_t *restrict attr, void *(*start)(void *), void *restrict arg)
; standard: POSIX.1-2024 XSH pthread_create
; deps: pthread_exit
; errno: EAGAIN, EINVAL, EPERM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-lifecycle
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Create a thread with an independent runtime stack and executable TLS.
; semantics: Use default attributes when attr is null. Otherwise honor detach state and the requested stack and guard sizes.
; semantics: Invoke start with arg and transport its pointer result to pthread_join.
; semantics: Publish the handle only on success. Return zero or a positive error and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_create:function
extern __al_thread_create:function

section .text.pthread_create alloc exec nowrite progbits
pthread_create:
    sub rsp, 8
    xor r8d, r8d
    call __al_thread_create
    cmp eax, 12                   ; ENOMEM is a POSIX creation resource error
    jne .done
    mov eax, 11                   ; EAGAIN
.done:
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
