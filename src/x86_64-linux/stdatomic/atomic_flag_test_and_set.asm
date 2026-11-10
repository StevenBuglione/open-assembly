; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atomic_flag_test_and_set
; header: stdatomic.h
; prototype: _Bool atomic_flag_test_and_set(volatile atomic_flag *object)
; standard: C17 7.17.8.1
; deps: atomic_flag_test_and_set_explicit
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:c17-atomic-ordering, reference:amd64-atomic-flag
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Atomically set the flag and return its previous value using sequential consistency.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atomic_flag_test_and_set:function
extern atomic_flag_test_and_set_explicit:function

section .text.atomic_flag_test_and_set alloc exec nowrite progbits
atomic_flag_test_and_set:
    sub rsp, 8
    mov esi, 5                   ; memory_order_seq_cst
    call atomic_flag_test_and_set_explicit
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
