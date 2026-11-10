; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_setsigdefault
; header: spawn.h
; prototype: int posix_spawnattr_setsigdefault(posix_spawnattr_t *restrict attr, const sigset_t *restrict value)
; standard: POSIX.1-2024 XSH posix_spawnattr_setsigdefault
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Store the selected default disposition mask in an initialized attribute object.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_setsigdefault:function

section .text.posix_spawnattr_setsigdefault alloc exec nowrite progbits
posix_spawnattr_setsigdefault:
    mov rax, [rdi]
    mov rdx, [rsi]
    mov [rax + 8], rdx
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
