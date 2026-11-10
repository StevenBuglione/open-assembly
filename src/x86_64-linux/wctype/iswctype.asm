; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iswctype
; header: wctype.h
; prototype: int iswctype(wint_t wc, wctype_t desc)
; standard: C17 7.30.2.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Test the class described by a wctype descriptor. Zero yields false.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iswctype:function
extern __al_unicode_mask:function

section .text.iswctype alloc exec nowrite progbits
iswctype:
    mov edi, edi
    test rsi, rsi
    jz .absent
    cmp rsi, 2048
    ja .absent
    lea rax, [rsi - 1]
    test rax, rsi
    jnz .absent
    push rbx
    mov ebx, esi
    call __al_unicode_mask
    and eax, ebx
    pop rbx
    ret
.absent:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
