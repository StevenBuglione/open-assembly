; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atol
; header: stdlib.h
; prototype: long atol(const char *s)
; standard: C17 7.22.1.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:decimal-integer
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Skip C-locale whitespace, then consume one optional sign and a run of decimal digits.
; semantics: Return the converted value, or zero when there are no digits. Do not change errno.
; semantics: Inputs whose converted value is outside the return type's range are outside the C17 contract.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atol:function
extern __al_strtox:function

section .text.atol alloc exec nowrite progbits
atol:
    push rbp
    mov rbp, rsp
    xor esi, esi                  ; no endptr
    mov edx, 10                   ; decimal
    mov ecx, 2                    ; signed, preserve errno
    call __al_strtox
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
