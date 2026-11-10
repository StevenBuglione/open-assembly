; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strtoul
; header: stdlib.h
; prototype: unsigned long strtoul(const char *restrict s, char **restrict endptr, int base)
; standard: C17 7.22.1.4
; deps: __errno_location
; errno: EINVAL, ERANGE
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:integer-scan
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Skip C-locale whitespace and one optional sign, then convert digits in base zero or 2 through 36.
; semantics: Base zero selects octal after a leading zero or decimal otherwise. Base zero and base 16 accept 0x or 0X only before a hex digit.
; semantics: Digit letters are case insensitive. C17 syntax has no binary prefix.
; semantics: On success, store the first unconverted byte through a non-NULL endptr and preserve errno.
; semantics: If the base is unsupported or no digits convert, return zero, set EINVAL and store s through a non-NULL endptr.
; semantics: On overflow consume the full digit run, store its end through a non-NULL endptr, and set ERANGE.
; semantics: Overflow returns the unsigned maximum. For a negative sign with representable magnitude, negate modulo 2^64.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strtoul:function
extern __al_strtox:function

section .text.strtoul alloc exec nowrite progbits
strtoul:
    push rbp
    mov rbp, rsp
    movsxd rdx, edx
    mov ecx, 1                    ; unsigned conversion
    call __al_strtox
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
