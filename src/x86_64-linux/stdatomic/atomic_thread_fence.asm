; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atomic_thread_fence
; header: stdatomic.h
; prototype: void atomic_thread_fence(memory_order order)
; standard: C17 7.17.4.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:c17-atomic-ordering, reference:amd64-atomic-flag
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Use a full AMD64 memory fence for sequential consistency. The compiler supplies ordering for inline fences.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atomic_thread_fence:function

section .text.atomic_thread_fence alloc exec nowrite progbits
atomic_thread_fence:
    mov edi, edi
    cmp edi, 5                   ; memory_order_seq_cst
    jne .done
    mfence
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
