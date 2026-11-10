; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: arena_reset
; header: arena.h
; prototype: int arena_reset(size_t state[3])
; standard: Extension ABI arena
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-state-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Clear the used word and preserve the base, capacity, and storage bytes.
; semantics: Return -EINVAL for a null state. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global arena_reset:function

section .text.arena_reset alloc exec nowrite progbits
arena_reset:
    test rdi, rdi
    jz .invalid
    mov qword [rdi + 16], 0
    xor eax, eax
    ret
.invalid:
    mov eax, -22                ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
