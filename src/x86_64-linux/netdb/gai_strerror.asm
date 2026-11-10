; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: gai_strerror
; header: netdb.h
; prototype: const char *gai_strerror(int code)
; standard: POSIX.1-2024 XSH gai_strerror
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:rfc3493, reference:local-netdb, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return an immutable error description for a netdb result code or an unknown-error description.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global gai_strerror:function

section .text.gai_strerror alloc exec nowrite progbits
gai_strerror:
    movsxd rdi, edi
    neg edi
    cmp edi, 12
    ja .unknown
    lea rax, [rel errors]
    test edi, edi
    jz .return
.next_byte:
    cmp byte [rax], 0
    lea rax, [rax + 1]
    jne .next_byte
    dec edi
    jnz .next_byte
.return:
    ret
.unknown:
    lea rax, [rel unknown_error]
    ret

section .rodata.gai_strerror alloc noexec nowrite progbits
errors:
    db "Success", 0
    db "Invalid address lookup flags", 0
    db "Name or service is unknown", 0
    db "Temporary failure in name resolution", 0
    db "Unrecoverable name resolution failure", 0
unknown_error:
    db "Unknown address lookup error", 0
    db "Address family is unsupported", 0
    db "Socket type is unsupported", 0
    db "Service is unsupported for the socket type", 0
    db "Unknown address lookup error", 0
    db "Address lookup allocation failed", 0
    db "System error in address lookup", 0
    db "Address lookup output is too large", 0

section .note.GNU-stack noalloc noexec nowrite progbits
