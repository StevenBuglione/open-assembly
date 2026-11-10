; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wscanf
; header: wchar.h
; prototype: int wscanf(const wchar_t *restrict format, ...)
; standard: C17 7.29.2.12
; deps: vwscanf
; errno: EILSEQ, EINVAL, EIO, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, reference:sysv-amd64, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: true
; semantics: Interpret C17 wide scan conversions, with field widths and consumed counts in wide characters.
; semantics: Return the number of assignments, or EOF when input fails before the first completed conversion.
; semantics: For c, s and scansets, l selects wchar_t output. Other character destinations receive multibyte text.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wscanf:function
extern vwscanf:function

section .text.wscanf alloc exec nowrite progbits
wscanf:
    push rbp
    mov rbp, rsp
    sub rsp, 208
    mov [rsp + 32], rdi
    mov [rsp + 40], rsi
    mov [rsp + 48], rdx
    mov [rsp + 56], rcx
    mov [rsp + 64], r8
    mov [rsp + 72], r9
    mov dword [rsp], 8
    mov dword [rsp + 4], 48
    lea rax, [rbp + 16]
    mov [rsp + 8], rax
    lea rax, [rsp + 32]
    mov [rsp + 16], rax
    lea rsi, [rsp]
    call vwscanf
    add rsp, 208
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
