; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wprintf
; header: wchar.h
; prototype: int wprintf(const wchar_t *restrict format, ...)
; standard: C17 7.29.2.11
; deps: vwprintf
; errno: EILSEQ, EINVAL, EIO, EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, reference:sysv-amd64, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: true
; semantics: Interpret C17 wide format conversions, with widths, precisions and counts in wide characters.
; semantics: Return the number of wide characters written or a negative value on failure.
; semantics: Establish wide orientation on an unoriented stream and preserve its captured output encoding.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wprintf:function
extern vwprintf:function

section .text.wprintf alloc exec nowrite progbits
wprintf:
    push rbp
    mov rbp, rsp
    sub rsp, 208
    mov [rsp + 32], rdi
    mov [rsp + 40], rsi
    mov [rsp + 48], rdx
    mov [rsp + 56], rcx
    mov [rsp + 64], r8
    mov [rsp + 72], r9
    movdqa [rsp + 80], xmm0
    movdqa [rsp + 96], xmm1
    movdqa [rsp + 112], xmm2
    movdqa [rsp + 128], xmm3
    movdqa [rsp + 144], xmm4
    movdqa [rsp + 160], xmm5
    movdqa [rsp + 176], xmm6
    movdqa [rsp + 192], xmm7
    mov dword [rsp], 8
    mov dword [rsp + 4], 48
    lea rax, [rbp + 16]
    mov [rsp + 8], rax
    lea rax, [rsp + 32]
    mov [rsp + 16], rax
    lea rsi, [rsp]
    call vwprintf
    add rsp, 208
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
