; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: arena_init
; header: arena.h
; prototype: int arena_init(size_t state[3], void *storage, size_t capacity)
; standard: Extension ABI arena
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-state-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize caller-owned base, capacity, and used words with used zero.
; semantics: Return -EINVAL for a null state or nonzero capacity with a null base, or -EOVERFLOW for a wrapping extent.
; semantics: Preserve state on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global arena_init:function

section .text.arena_init alloc exec nowrite progbits
arena_init:
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jnz .extent
    test rdx, rdx
    jnz .invalid
.extent:
    mov rax, rsi
    add rax, rdx
    jc .overflow
    mov [rdi], rsi
    mov [rdi + 8], rdx
    mov qword [rdi + 16], 0
    xor eax, eax
    ret
.invalid:
    mov eax, -22                ; EINVAL
    ret
.overflow:
    mov eax, -75                ; EOVERFLOW
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
