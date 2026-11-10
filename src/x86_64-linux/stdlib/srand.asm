; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: srand
; header: stdlib.h
; prototype: void srand(unsigned int seed)
; standard: C17 7.22.2.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:c17-rand-repeatability
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Replace the shared generator state with the specified unsigned seed.
; semantics: Equal seeds reproduce the same subsequent sequence.
; semantics: Serialize updates to the shared sequence. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global srand:function
extern __al_rand_state:data
extern __al_lock:function
extern __al_unlock:function

section .text.srand alloc exec nowrite progbits
srand:
    push rbx
    push r12
    sub rsp, 8
    mov r12d, edi
    lea rbx, [rel __al_rand_state]
    lea rdi, [rbx + 8]
    call __al_lock
    mov [rbx], r12
    lea rdi, [rbx + 8]
    call __al_unlock
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
