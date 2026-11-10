; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_getpgroup
; header: spawn.h
; prototype: int posix_spawnattr_getpgroup(const posix_spawnattr_t *restrict attr, pid_t *restrict value)
; standard: POSIX.1-2024 XSH posix_spawnattr_getpgroup
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the nonnegative target process group from an initialized attribute object through value.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_getpgroup:function

section .text.posix_spawnattr_getpgroup alloc exec nowrite progbits
posix_spawnattr_getpgroup:
    mov rax, [rdi]
    mov edx, [rax + 20]
    mov [rsi], edx
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
