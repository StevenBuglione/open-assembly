; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vfscanf
; header: stdio.h
; prototype: int vfscanf(FILE *restrict stream, const char *restrict format, va_list args)
; standard: C17 7.21.6.9
; deps: -
; errno: EINVAL, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret the integer, floating, byte, string, pointer, count, percent and bracket-set conversions.
; semantics: Apply widths and assignment suppression. Preserve the first input byte after a matching item.
; semantics: Return the number of assignments, or EOF if input fails before the first completed conversion.
; semantics: Unsupported wide conversions report EINVAL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vfscanf:function
extern __al_vscan:function

section .text.vfscanf alloc exec nowrite progbits
vfscanf:
    push rbp
    mov rbp, rsp
    mov ecx, 1
    call __al_vscan
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
