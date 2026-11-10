; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vfwprintf
; header: wchar.h
; prototype: int vfwprintf(FILE *restrict stream, const wchar_t *restrict format, va_list args)
; standard: C17 7.29.2.5
; deps: -
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

global vfwprintf:function
extern __al_vformat:function

section .text.vfwprintf alloc exec nowrite progbits
vfwprintf:
    push rbp
    mov rbp, rsp
    mov rcx, rdx
    mov rdx, rsi
    xor esi, esi
    mov r8d, 4
    call __al_vformat
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
