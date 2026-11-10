; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vprintf
; header: stdio.h
; prototype: int vprintf(const char *restrict format, va_list args)
; standard: C17 7.21.6.10
; deps: vfprintf
; errno: EILSEQ, EINVAL, EOVERFLOW, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret the integer, floating, string, byte, pointer, count, and percent conversions.
; semantics: Return the byte count excluding the terminator on success, or a negative result on error.
; semantics: Wide c and s encode arguments with the active LC_CTYPE. String precision limits complete multibyte characters by byte count. Count overflow reports EOVERFLOW.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vprintf:function
extern vfprintf:function
extern stdout:data

section .text.vprintf alloc exec nowrite progbits
vprintf:
    push rbp
    mov rbp, rsp
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, [rel stdout]
    call vfprintf
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
