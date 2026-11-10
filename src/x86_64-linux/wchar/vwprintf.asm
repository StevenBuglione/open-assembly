; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vwprintf
; header: wchar.h
; prototype: int vwprintf(const wchar_t *restrict format, va_list args)
; standard: C17 7.29.2.9
; deps: vfwprintf
; errno: EILSEQ, EINVAL, EIO, EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, reference:sysv-amd64, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret C17 wide format conversions, with widths, precisions and counts in wide characters.
; semantics: Return the number of wide characters written or a negative value on failure.
; semantics: Establish wide orientation on an unoriented stream and preserve its captured output encoding.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vwprintf:function
extern vfwprintf:function
extern stdout:data

section .text.vwprintf alloc exec nowrite progbits
vwprintf:
    push rbp
    mov rbp, rsp
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, [rel stdout]
    call vfwprintf
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
