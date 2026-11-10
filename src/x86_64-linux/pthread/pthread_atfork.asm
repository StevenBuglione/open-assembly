; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_atfork
; header: pthread.h
; prototype: int pthread_atfork(void (*prepare)(void), void (*parent)(void), void (*child)(void))
; standard: POSIX.1-2024 XSH pthread_atfork
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:threaded-fork, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Append a registration of optional prepare, parent and child fork callbacks.
; semantics: Preserve errno and return ENOMEM when the 32-registration registry is full.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_atfork:function
global __al_atfork_state:data
extern __al_lock:function
extern __al_unlock:function

section .text.pthread_atfork alloc exec nowrite progbits
pthread_atfork:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    lea rbx, [rel __al_atfork_state]
    mov rdi, rbx
    call __al_lock
    mov ecx, [rbx + 4]
    mov r15d, 12              ; ENOMEM
    cmp ecx, 32
    jae .unlock
    lea eax, [rcx + rcx * 2]
    shl eax, 3
    mov [rbx + rax + 8], r12
    mov [rbx + rax + 16], r13
    mov [rbx + rax + 24], r14
    inc ecx
    mov [rbx + 4], ecx
    xor r15d, r15d
.unlock:
    mov rdi, rbx
    call __al_unlock
    mov eax, r15d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.pthread_atfork alloc noexec write nobits align=8
__al_atfork_state:
    resd 2                    ; guard and published registration count
    resq 96                   ; 32 prepare, parent, child triples

section .note.GNU-stack noalloc noexec nowrite progbits
