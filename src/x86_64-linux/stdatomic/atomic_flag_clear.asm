; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atomic_flag_clear
; header: stdatomic.h
; prototype: void atomic_flag_clear(volatile atomic_flag *object)
; standard: C17 7.17.8.2
; deps: atomic_flag_clear_explicit
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:c17-atomic-ordering, reference:amd64-atomic-flag
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Atomically clear the flag using sequential consistency.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atomic_flag_clear:function
extern atomic_flag_clear_explicit:function

section .text.atomic_flag_clear alloc exec nowrite progbits
atomic_flag_clear:
    sub rsp, 8
    mov esi, 5                   ; memory_order_seq_cst
    call atomic_flag_clear_explicit
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
