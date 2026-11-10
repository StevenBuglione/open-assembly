; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atomic_flag_test_and_set_explicit
; header: stdatomic.h
; prototype: _Bool atomic_flag_test_and_set_explicit(volatile atomic_flag *object, memory_order order)
; standard: C17 7.17.8.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:c17-atomic-ordering, reference:amd64-atomic-flag
; provenance: original
; narrow_args: esi:u32
; variadic: false
; semantics: Atomically exchange the previous byte for true. The locked AMD64 exchange is sufficient for every valid order.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atomic_flag_test_and_set_explicit:function

section .text.atomic_flag_test_and_set_explicit alloc exec nowrite progbits
atomic_flag_test_and_set_explicit:
    mov esi, esi
    mov eax, 1
    xchg byte [rdi], al
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
