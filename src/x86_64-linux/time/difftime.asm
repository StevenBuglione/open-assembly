; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: difftime
; header: time.h
; prototype: double difftime(time_t later, time_t earlier)
; standard: C17 7.27.2.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:gregorian-utc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute later minus earlier across the full signed time64 input range.
; semantics: Round the integer difference once to double in the current SSE floating-point rounding mode.
; semantics: Preserve errno and floating-point control state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global difftime:function

section .text.difftime alloc exec nowrite progbits
difftime:
    mov rax, rdi
    sub rax, rsi
    jno .signed
    test rdi, rdi
    jns .wide
    neg rax                       ; unsigned magnitude of negative overflow
.wide:
    mov rcx, rax
    and ecx, 1
    shr rax, 1
    or rax, rcx                  ; retain the discarded bit for rounding
    test rdi, rdi
    jns .scaled
    neg rax                       ; convert with the correct directed sign
.scaled:
    cvtsi2sd xmm0, rax
    addsd xmm0, xmm0             ; exact scale back to the original magnitude
    ret
.signed:
    cvtsi2sd xmm0, rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
