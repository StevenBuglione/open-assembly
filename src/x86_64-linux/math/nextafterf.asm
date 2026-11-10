; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nextafterf
; header: math.h
; prototype: float nextafterf(float x, float y)
; standard: C17 7.12.11.3
; deps: feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the next representable value after x in the direction of y, independently of the rounding mode.
; semantics: If x and y compare equal return y, including its sign of zero. A step into subnormal range or from finite to infinity sets ERANGE and the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global nextafterf:function
extern __al_math_next:function

section .text.nextafterf alloc exec nowrite progbits
nextafterf:
    movd r8d, xmm1
    xor r9d, r9d
    mov ecx, 0
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_next
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
