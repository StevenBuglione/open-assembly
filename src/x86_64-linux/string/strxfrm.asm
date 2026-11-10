; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strxfrm
; header: string.h
; prototype: size_t strxfrm(char *restrict dest, const char *restrict src, size_t n)
; standard: C17 7.24.4.5
; deps: strlen, memcpy
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: In the C locale the transformation is the source string unchanged. Return its length excluding NUL.
; semantics: If n exceeds the returned length, copy the source and terminator. Otherwise leave dest unchanged.
; semantics: Dest may be NULL when n is zero. The regions must not overlap.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strxfrm:function
extern strlen:function
extern memcpy:function

section .text.strxfrm alloc exec nowrite progbits
strxfrm:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov [rsp], rdi                ; dest
    mov [rsp + 8], rsi            ; src
    mov [rsp + 16], rdx           ; dest capacity
    mov rdi, rsi
    call strlen
    cmp rax, [rsp + 16]
    jae .done

    ; C collation uses an identity transform including the terminator.
    mov [rsp + 24], rax
    mov rdi, [rsp]
    mov rsi, [rsp + 8]
    lea rdx, [rax + 1]
    call memcpy
    mov rax, [rsp + 24]
.done:
    add rsp, 32
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
