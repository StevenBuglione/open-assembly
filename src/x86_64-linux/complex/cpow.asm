; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cpow
; header: complex.h
; prototype: double _Complex cpow(double _Complex x, double _Complex y)
; standard: C17 7.3.8.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return x raised to the complex exponent y. Use the principal logarithm with the negative real branch cut of the base. Preserve the caller's floating control state.
; semantics: A zero exponent returns one for a non-signaling base. A nonnegative real base with a real exponent follows scalar pow range effects.
; semantics: A zero or infinite base with a finite real exponent uses its limiting magnitude in the principal quadrant. Other nonfinite cases with no defined limit return quiet NaNs with the invalid exception and EDOM when a domain error occurs.
; semantics: Assess underflow and overflow separately for each final component. Annex G permits additional floating exceptions from intermediate calculation.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cpow:function
extern __al_complex_power:function

section .text.cpow alloc exec nowrite progbits
cpow:
    movq rsi, xmm0
    movq rcx, xmm1
    xor edx, edx
    xor r8d, r8d
    mov edi, 1
    sub rsp, 8
    call __al_complex_power
    movq xmm0, rax
    movq xmm1, rcx
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
