; Test-only SysV scalar floating argument adapter.
bits 64
default rel

global phase7_scalar_abi_probe:function
extern phase2_abi_probe

section .text

; unsigned phase7_scalar_abi_probe(uintptr_t function, uint64_t first, uint64_t second)
; Present the target and the two raw scalar argument words to the shared probe.
phase7_scalar_abi_probe:
    sub rsp, 56
    mov [rsp], rdi
    mov [rsp + 8], rsi
    mov [rsp + 16], rdx
    mov qword [rsp + 24], 0
    mov qword [rsp + 32], 0
    mov qword [rsp + 40], 0
    lea rdi, [rel enter_scalar]
    mov rsi, rsp
    call phase2_abi_probe
    add rsp, 56
    ret

; Inherit the probe's entry stack and preserved-state sentinels. The target
; returns directly to its probe, so this adapter cannot hide a state change.
enter_scalar:
    movq xmm0, rsi
    movq xmm1, rdx
    jmp rdi

section .note.GNU-stack noalloc noexec nowrite progbits
