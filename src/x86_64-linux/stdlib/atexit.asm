; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atexit
; header: stdlib.h
; prototype: int atexit(void (*func)(void))
; standard: C17 7.22.4.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, reference:runtime-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Register a valid void(void) callback for normal termination; a null callback is outside the contract.
; semantics: There are 32 pending slots; return zero on success or a nonzero value when all slots are occupied.
; semantics: Each registration counts separately, even when it names a previously registered function.
; semantics: A running callback's slot is no longer pending; it may register another callback before returning.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atexit:function
global __al_atexit_state:data
extern __al_lock:function
extern __al_unlock:function

section .text.atexit alloc exec nowrite progbits
atexit:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rsp], rdi                ; callback
    lea rdi, [rel __al_atexit_state]
    call __al_lock

    lea rdx, [rel __al_atexit_state]
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
    lea rdi, [rel __al_atexit_state]
    call __al_unlock
    mov eax, [rsp + 8]
    add rsp, 16
    pop rbp
    ret

section .bss.atexit alloc noexec write nobits align=8
__al_atexit_state:
    resd 1                        ; lock
    resd 1                        ; pending count
    resq 32                       ; callback stack

section .note.GNU-stack noalloc noexec nowrite progbits
