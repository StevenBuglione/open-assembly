; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: memmove
; header: string.h
; prototype: void *memmove(void *dest, const void *src, size_t n)
; standard: C17 7.24.2.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-ranges
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Copy exactly n bytes as though through temporary storage and return dest.
; semantics: Support overlap in either direction and identical pointers. With zero length, access neither region.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global memmove:function

section .text.memmove alloc exec nowrite progbits
memmove:
    mov rax, rdi
    test rdx, rdx
    jz .done
    cmp rdi, rsi
    je .done
    jb .forward

    ; Copy backward only when dest starts inside the source region.
    mov rcx, rdi
    sub rcx, rsi
    cmp rcx, rdx
    jae .forward
.backward:
    dec rdx
    mov cl, [rsi + rdx]
    mov [rdi + rdx], cl
    test rdx, rdx
    jnz .backward
    ret

.forward:
    mov cl, [rsi]
    mov [rdi], cl
    inc rsi
    inc rdi
    dec rdx
    jnz .forward
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
