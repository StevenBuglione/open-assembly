; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_cond_destroy
; header: pthread.h
; prototype: int pthread_cond_destroy(pthread_cond_t *cond)
; standard: POSIX.1-2024 XSH pthread_cond_destroy
; deps: -
; errno: EBUSY, EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Invalidate an unused condition variable. Report EBUSY while a registered waiter remains.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_cond_destroy:function
extern __al_lock:function
extern __al_unlock:function

section .text.pthread_cond_destroy alloc exec nowrite progbits
pthread_cond_destroy:
    test rdi, rdi
    jz .invalid
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    call __al_lock
    mov r12d, 22
    cmp dword [rbx + 12], 0
    jne .unlock
    mov r12d, 16
    cmp dword [rbx + 8], 0
    jne .unlock
    mov dword [rbx + 12], -1
    xor r12d, r12d
.unlock:
    mov rdi, rbx
    call __al_unlock
    mov eax, r12d
    add rsp, 8
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
