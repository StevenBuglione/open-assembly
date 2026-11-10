; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_getflags
; header: spawn.h
; prototype: int posix_spawnattr_getflags(const posix_spawnattr_t *restrict attr, short *restrict value)
; standard: POSIX.1-2024 XSH posix_spawnattr_getflags
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the selected spawn flags from an initialized attribute object through value.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_getflags:function

section .text.posix_spawnattr_getflags alloc exec nowrite progbits
posix_spawnattr_getflags:
    mov rax, [rdi]
    mov dx, [rax + 16]
    mov [rsi], dx
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
