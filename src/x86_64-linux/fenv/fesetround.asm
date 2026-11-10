; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fesetround
; header: fenv.h
; prototype: int fesetround(int mode)
; standard: C17 7.6.3.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Set the supported rounding mode in x87 and SSE, preserving all other controls and flags.
; semantics: Return zero for a supported mode, otherwise nonzero without changing the state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fesetround:function

section .text.fesetround alloc exec nowrite progbits
fesetround:
    movsxd rdi, edi
    cmp rdi, 3072
    ja .invalid
    test rdi, 1023
    jnz .invalid
    sub rsp, 8
    stmxcsr [rsp]
    fnstcw [rsp + 4]
    and word [rsp + 4], 0xf3ff
    or [rsp + 4], di
    shl edi, 3
    and dword [rsp], 0xffff9fff
    or [rsp], edi
    fldcw [rsp + 4]
    ldmxcsr [rsp]
    add rsp, 8
    xor eax, eax
    ret
.invalid:
    mov eax, -1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
