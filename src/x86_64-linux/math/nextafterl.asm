; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nextafterl
; header: math.h
; prototype: long double nextafterl(long double x, long double y)
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

global nextafterl:function
extern __al_math_next:function

section .text.nextafterl alloc exec nowrite progbits
nextafterl:
    mov r8, [rsp + 24]
    movzx r9d, word [rsp + 32]
    mov ecx, 2
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_next
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
