; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vswprintf
; header: wchar.h
; prototype: int vswprintf(wchar_t *restrict dest, size_t size, const wchar_t *restrict format, va_list args)
; standard: C17 7.29.2.7
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
; semantics: Reserve space for a terminating wide null. A result that does not fit returns a negative value.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vswprintf:function
extern __al_vformat:function

section .text.vswprintf alloc exec nowrite progbits
vswprintf:
    push rbp
    mov rbp, rsp
    mov r8d, 3
    call __al_vformat
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
