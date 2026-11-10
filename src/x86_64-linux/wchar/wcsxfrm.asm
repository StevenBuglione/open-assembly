; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsxfrm
; header: wchar.h
; prototype: size_t wcsxfrm(wchar_t *restrict dst, const wchar_t *restrict src, size_t n)
; standard: C17 7.29.4.4.4
; deps: wcslen, wmemcpy
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the source length. Write the identity collation key including its null only when it fits.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsxfrm:function
extern wcslen:function
extern wmemcpy:function

section .text.wcsxfrm alloc exec nowrite progbits
wcsxfrm:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, rsi
    call wcslen
    mov r14, rax
    cmp rax, r13
    jae .done
    mov rdi, rbx
    mov rsi, r12
    lea rdx, [rax + 1]
    call wmemcpy
.done:
    mov rax, r14
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
