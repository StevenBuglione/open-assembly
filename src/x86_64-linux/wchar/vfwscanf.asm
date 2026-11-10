; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vfwscanf
; header: wchar.h
; prototype: int vfwscanf(FILE *restrict stream, const wchar_t *restrict format, va_list args)
; standard: C17 7.29.2.6
; deps: -
; errno: EILSEQ, EINVAL, EIO, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, reference:sysv-amd64, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret C17 wide scan conversions, with field widths and consumed counts in wide characters.
; semantics: Return the number of assignments, or EOF when input fails before the first completed conversion.
; semantics: For c, s and scansets, l selects wchar_t output. Other character destinations receive multibyte text.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vfwscanf:function
extern __al_vscan:function

section .text.vfwscanf alloc exec nowrite progbits
vfwscanf:
    push rbp
    mov rbp, rsp
    mov ecx, 3
    call __al_vscan
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
