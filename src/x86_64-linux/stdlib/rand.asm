; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: rand
; header: stdlib.h
; prototype: int rand(void)
; standard: C17 7.22.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:c17-rand-repeatability
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the next pseudorandom integer between zero and RAND_MAX inclusive.
; semantics: A call before any srand uses the sequence for seed one.
; semantics: Serialize updates to the shared sequence. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global rand:function
global __al_rand_state:data
extern __al_lock:function
extern __al_unlock:function

section .text.rand alloc exec nowrite progbits
rand:
    push rbx
    push r12
    sub rsp, 8
    lea rbx, [rel __al_rand_state]
    lea rdi, [rbx + 8]
    call __al_lock
    mov rax, [rbx]
    mov rcx, 6364136223846793005   ; full-period 64-bit LCG multiplier
    imul rax, rcx
    mov rcx, 1442695040888963407   ; odd increment
    add rax, rcx
    mov [rbx], rax
    shr rax, 33                   ; use the upper 31 bits
    mov r12d, eax
    lea rdi, [rbx + 8]
    call __al_unlock
    mov eax, r12d
    add rsp, 8
    pop r12
    pop rbx
    ret

section .data.rand alloc noexec write progbits align=8
__al_rand_state:
    dq 1
    dd 0

section .note.GNU-stack noalloc noexec nowrite progbits
