; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: free
; header: stdlib.h
; prototype: void free(void *ptr)
; standard: C17 7.22.3.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Accept NULL or a live allocation pointer returned by the memory allocation family. NULL is a no-op.
; semantics: Release the allocation and preserve errno. Interior, stale and foreign pointers are outside the contract.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global free:function
extern __al_heap:function

section .text.free alloc exec nowrite progbits
free:
    push rbp
    mov rbp, rsp
    xor esi, esi
    mov edx, 16
    mov ecx, 1                    ; free
    call __al_heap
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
