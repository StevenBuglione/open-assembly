; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutex_unlock
; header: pthread.h
; prototype: int pthread_mutex_unlock(pthread_mutex_t *mutex)
; standard: POSIX.1-2024 XSH pthread_mutex_unlock
; deps: __errno_location
; errno: EINVAL, EPERM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release one level of ownership. The final release makes the mutex available and wakes a waiter.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutex_unlock:function
extern __errno_location:function
extern __al_unlock:function

section .text.pthread_mutex_unlock alloc exec nowrite progbits
pthread_mutex_unlock:
    test rdi, rdi
    jz .invalid
    cmp qword [rdi + 24], 0
    jne .invalid
    push rbx
    mov rbx, rdi
    call __errno_location
    mov rax, [rax + 8]
    cmp [rbx + 8], rax
    jne .not_owner
    mov eax, [rbx + 16]
    test eax, eax
    jz .not_owner
    dec eax
    mov [rbx + 16], eax
    jnz .success
    mov qword [rbx + 8], 0
    mov rdi, rbx
    call __al_unlock
.success:
    xor eax, eax
    pop rbx
    ret
.not_owner:
    mov eax, 1
    pop rbx
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
