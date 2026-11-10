; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: htonl
; header: arpa/inet.h
; prototype: uint32_t htonl(uint32_t value)
; standard: POSIX.1-2024 XSH htonl
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Reverse the byte order of a 32-bit integer on x86-64.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global htonl:function

section .text.htonl alloc exec nowrite progbits
htonl:
    mov eax, edi
    bswap eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
