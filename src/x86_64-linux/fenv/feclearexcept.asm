; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: feclearexcept
; header: fenv.h
; prototype: int feclearexcept(int excepts)
; standard: C17 7.6.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Clear the requested standard exception flags from both x87 and SSE.
; semantics: Preserve the other flags, rounding modes and exception masks. Return zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global feclearexcept:function

section .text.feclearexcept alloc exec nowrite progbits
feclearexcept:
    movsxd rdi, edi
    and edi, 61
    jz .empty
    sub rsp, 32
    fnstenv [rsp]
    stmxcsr [rsp + 28]
    mov eax, edi
    not eax
    and [rsp + 4], ax             ; x87 status, independent of its control word
    movzx eax, word [rsp]
    not eax
    and eax, 63                  ; unmasked exceptions
    movzx edx, word [rsp + 4]
    test eax, edx
    jnz .sse
    and word [rsp + 4], 0x7f7f   ; clear summary when no unmasked flags remain
.sse:
    test edi, 1
    jz .skip_invalid
    and dword [rsp + 28], -2
.skip_invalid:
    test edi, 4
    jz .skip_divide
    and dword [rsp + 28], -5
.skip_divide:
    test edi, 8
    jz .skip_overflow
    and dword [rsp + 28], -9
.skip_overflow:
    test edi, 16
    jz .skip_underflow
    and dword [rsp + 28], -17
.skip_underflow:
    test edi, 32
    jz .skip_inexact
    and dword [rsp + 28], -33
.skip_inexact:
    fldenv [rsp]
    ldmxcsr [rsp + 28]
    add rsp, 32
.empty:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
