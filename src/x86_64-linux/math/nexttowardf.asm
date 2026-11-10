; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nexttowardf
; header: math.h
; prototype: float nexttowardf(float x, long double y)
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

global nexttowardf:function
extern __al_math_next:function

section .text.nexttowardf alloc exec nowrite progbits
nexttowardf:
    mov r8, [rsp + 8]
    movzx r9d, word [rsp + 16]
    mov ecx, 2
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_next
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
