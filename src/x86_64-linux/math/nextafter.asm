; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nextafter
; header: math.h
; prototype: double nextafter(double x, double y)
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

global nextafter:function
extern __al_math_next:function

section .text.nextafter alloc exec nowrite progbits
nextafter:
    movq r8, xmm1
    xor r9d, r9d
    mov ecx, 1
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_next
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
