; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nexttowardl
; header: math.h
; prototype: long double nexttowardl(long double x, long double y)
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

global nexttowardl:function
extern __al_math_next:function

section .text.nexttowardl alloc exec nowrite progbits
nexttowardl:
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
