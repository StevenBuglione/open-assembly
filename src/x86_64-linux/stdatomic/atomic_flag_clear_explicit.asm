; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atomic_flag_clear_explicit
; header: stdatomic.h
; prototype: void atomic_flag_clear_explicit(volatile atomic_flag *object, memory_order order)
; standard: C17 7.17.8.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:c17-atomic-ordering, reference:amd64-atomic-flag
; provenance: original
; narrow_args: esi:u32
; variadic: false
; semantics: Clear the flag with a locked exchange for sequential consistency and an aligned byte store for relaxed or release order.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atomic_flag_clear_explicit:function

section .text.atomic_flag_clear_explicit alloc exec nowrite progbits
atomic_flag_clear_explicit:
    mov esi, esi
    cmp esi, 5                   ; memory_order_seq_cst
    jne .release_store
    xor eax, eax
    xchg byte [rdi], al
    ret
.release_store:
    mov byte [rdi], 0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
