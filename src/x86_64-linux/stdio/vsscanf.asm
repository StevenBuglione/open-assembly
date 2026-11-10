; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vsscanf
; header: stdio.h
; prototype: int vsscanf(const char *restrict src, const char *restrict format, va_list args)
; standard: C17 7.21.6.14
; deps: -
; errno: EILSEQ, EINVAL, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret the integer, floating, byte, string, pointer, count, percent and bracket-set conversions.
; semantics: Apply widths and assignment suppression. Preserve the first input byte after a matching item.
; semantics: Return the number of assignments, or EOF if input fails before the first completed conversion.
; semantics: Wide c, s and bracket conversions decode the selected byte field from an initial multibyte state. Incomplete or malformed encodings report EILSEQ.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vsscanf:function
extern __al_vscan:function

section .text.vsscanf alloc exec nowrite progbits
vsscanf:
    push rbp
    mov rbp, rsp
    xor ecx, ecx
    call __al_vscan
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
