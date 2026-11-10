; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: htons
; header: arpa/inet.h
; prototype: uint16_t htons(uint16_t value)
; standard: POSIX.1-2024 XSH htons
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: di:u16
; variadic: false
; semantics: Reverse the byte order of a 16-bit integer on x86-64.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global htons:function

section .text.htons alloc exec nowrite progbits
htons:
    movzx eax, di
    rol ax, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
