; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vscanf
; header: stdio.h
; prototype: int vscanf(const char *restrict format, va_list args)
; standard: C17 7.21.6.11
; deps: vfscanf
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

global vscanf:function
extern vfscanf:function
extern stdin:data

section .text.vscanf alloc exec nowrite progbits
vscanf:
    push rbp
    mov rbp, rsp
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, [rel stdin]
    call vfscanf
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
