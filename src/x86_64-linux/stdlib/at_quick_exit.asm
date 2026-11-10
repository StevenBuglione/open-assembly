; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: at_quick_exit
; header: stdlib.h
; prototype: int at_quick_exit(void (*function)(void))
; standard: C17 7.22.4.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:c17-quick-exit, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Register a callback for quick termination in a registry independent of normal termination.
; semantics: Accept 32 pending registrations. Return zero on success or nonzero when the registry is full.
; semantics: Count each registration separately. Running callbacks can reuse a slot after it is popped.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global at_quick_exit:function
global __al_quick_exit_state:data
extern __al_lock:function
extern __al_unlock:function

section .text.at_quick_exit alloc exec nowrite progbits
at_quick_exit:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rsp], rdi                ; callback
    lea rdi, [rel __al_quick_exit_state]
    call __al_lock

    lea rdx, [rel __al_quick_exit_state]
    mov eax, [rdx + 4]            ; pending count
    cmp eax, 32
    jae .full
    mov rcx, [rsp]
    mov [rdx + rax*8 + 8], rcx
    inc eax
    mov [rdx + 4], eax
    xor eax, eax
    jmp .unlock

.full:
    mov eax, 1
.unlock:
    mov [rsp + 8], eax
    lea rdi, [rel __al_quick_exit_state]
    call __al_unlock
    mov eax, [rsp + 8]
    add rsp, 16
    pop rbp
    ret

section .bss.at_quick_exit alloc noexec write nobits align=8
__al_quick_exit_state:
    resd 1                        ; lock
    resd 1                        ; pending count
    resq 32                       ; callback stack

section .note.GNU-stack noalloc noexec nowrite progbits
