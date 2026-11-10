; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: memcpy
; header: string.h
; prototype: void *memcpy(void *restrict dest, const void *restrict src, size_t n)
; standard: C17 7.24.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-ranges
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Copy exactly n bytes from src to the disjoint destination and return dest.
; semantics: Overlapping regions are outside the contract. With zero length, access neither region.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global memcpy:function
extern __al_memcpy_bulk:function

section .text.memcpy alloc exec nowrite progbits
memcpy:
    mov rax, rdi
    test rdx, rdx
    jz .done
    cmp rdx, 256
    jae .bulk
.next:
    mov cl, [rsi]
    mov [rdi], cl
    inc rsi
    inc rdi
    dec rdx
    jnz .next
.done:
    ret
.bulk:
    sub rsp, 8
    call __al_memcpy_bulk
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
