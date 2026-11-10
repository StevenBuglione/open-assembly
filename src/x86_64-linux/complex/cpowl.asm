; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cpowl
; header: complex.h
; prototype: long double _Complex cpowl(long double _Complex x, long double _Complex y)
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

global cpowl:function
extern __al_complex_power:function

section .text.cpowl alloc exec nowrite progbits
cpowl:
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    movq xmm2, qword [rsp + 40]
    movq xmm3, qword [rsp + 56]
    movzx r10d, word [rsp + 48]
    movzx r11d, word [rsp + 64]
    shl r11d, 16
    or r10d, r11d
    movq xmm4, r10
    mov edi, 2
    sub rsp, 40
    call __al_complex_power
    mov [rsp], rax
    mov [rsp + 8], dx
    mov [rsp + 16], rcx
    mov [rsp + 24], r8w
    fld tword [rsp + 16]
    fld tword [rsp]
    add rsp, 40
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
