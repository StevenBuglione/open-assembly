; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nexttoward
; header: math.h
; prototype: double nexttoward(double x, long double y)
; standard: C17 7.12.11.4
; deps: feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Step one representable value from x toward y, comparing y at extended precision.
; semantics: Equal operands return y converted to the return type. A step into subnormal range or from finite to infinity sets ERANGE and the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global nexttoward:function
extern __al_math_next:function

section .text.nexttoward alloc exec nowrite progbits
nexttoward:
    mov r8, [rsp + 8]
    movzx r9d, word [rsp + 16]
    mov ecx, 2
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_next
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
