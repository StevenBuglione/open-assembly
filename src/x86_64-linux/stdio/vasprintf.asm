; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vasprintf
; header: stdio.h
; prototype: int vasprintf(char **restrict result, const char *restrict format, va_list args)
; standard: Extension ABI vasprintf
; deps: malloc, realloc, free
; errno: EILSEQ, EINVAL, ENOMEM, EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret the same byte, integer, floating and wide-argument conversions as vfprintf.
; semantics: Perform count stores in format order exactly once, including when buffers grow.
; semantics: On success return the byte count excluding the NUL and publish a caller-owned allocation.
; semantics: Empty output still produces a valid NUL-terminated allocation.
; semantics: On error free temporary storage, set the output pointer to null, and return a negative value with errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vasprintf:function
extern __al_vformat:function

section .text.vasprintf alloc exec nowrite progbits
vasprintf:
    push rbp
    mov rbp, rsp
    mov rcx, rdx
    mov rdx, rsi
    xor esi, esi
    mov r8d, 2                   ; allocated string sink
    call __al_vformat
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
