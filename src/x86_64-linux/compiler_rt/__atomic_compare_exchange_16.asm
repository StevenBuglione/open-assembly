; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_compare_exchange_16
; header: compiler_rt.h
; prototype: _Bool __atomic_compare_exchange_16(volatile void *object, void *expected, unsigned __int128 desired, int success_order, int failure_order)
; standard: Runtime ABI __atomic_compare_exchange_16
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: r8d:s32, r9d:s32
; variadic: false
; semantics: Atomically replace a matching 16-byte object. On mismatch, publish the observed bytes to expected.
; semantics: Use sequentially consistent ordering and the baseline alignment policy.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_compare_exchange_16:function
extern __al_atomic_quad:function

section .text.__atomic_compare_exchange_16 alloc exec nowrite progbits
__atomic_compare_exchange_16:
    mov r8, rsi                   ; expected bytes
    mov rsi, rdx                  ; desired low and high halves
    mov rdx, rcx
    mov ecx, 8
    sub rsp, 8
    call __al_atomic_quad
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
