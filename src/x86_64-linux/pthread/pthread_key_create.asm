; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_key_create
; header: pthread.h
; prototype: int pthread_key_create(pthread_key_t *key, void (*destructor)(void *))
; standard: POSIX.1-2024 XSH pthread_key_create
; deps: -
; errno: EAGAIN
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:thread-specific-data
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Allocate a process-visible key with a null initial value in all threads.
; semantics: Associate the optional destructor and publish the key only on success.
; semantics: Return EAGAIN when the fixed capacity is exhausted. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_key_create:function
global __al_tsd_keys:data
global __al_tsd_lock:data
extern __al_lock:function
extern __al_unlock:function

section .text.pthread_key_create alloc exec nowrite progbits
pthread_key_create:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    lea rdi, [rel __al_tsd_lock]
    call __al_lock
    lea rbx, [rel __al_tsd_keys]
    xor edx, edx
.scan:
    mov rax, [rbx]
    test al, 1
    jnz .next
    cmp rax, -2                     ; retired before a generation can wrap
    je .next
    inc rax
    mov [rbx], rax
    mov [rbx + 8], r13
    mov [r12], edx
    xor ebx, ebx
    jmp .done
.next:
    add rbx, 16
    inc edx
    cmp edx, 128
    jb .scan
    mov ebx, 11                    ; EAGAIN
.done:
    lea rdi, [rel __al_tsd_lock]
    call __al_unlock
    mov eax, ebx
    pop r13
    pop r12
    pop rbx
    ret

section .bss.pthread_key_create alloc noexec write nobits align=8
__al_tsd_keys: resq 256
__al_tsd_lock: resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
