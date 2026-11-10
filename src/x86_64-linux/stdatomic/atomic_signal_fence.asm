; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atomic_signal_fence
; header: stdatomic.h
; prototype: void atomic_signal_fence(memory_order order)
; standard: C17 7.17.4.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:c17-atomic-ordering, reference:amd64-atomic-flag
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Provide the out-of-line compiler ordering boundary without issuing a hardware fence.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atomic_signal_fence:function

section .text.atomic_signal_fence alloc exec nowrite progbits
atomic_signal_fence:
    mov edi, edi
    ret                          ; the compiler supplies the signal ordering boundary

section .note.GNU-stack noalloc noexec nowrite progbits
