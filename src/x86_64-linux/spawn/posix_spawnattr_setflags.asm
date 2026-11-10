; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_setflags
; header: spawn.h
; prototype: int posix_spawnattr_setflags(posix_spawnattr_t *restrict attr, short value)
; standard: POSIX.1-2024 XSH posix_spawnattr_setflags
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: si:s16
; variadic: false
; semantics: Store the selected spawn flags in an initialized attribute object.
; semantics: Reject an unsupported value with EINVAL and leave the stored field unchanged.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_setflags:function

section .text.posix_spawnattr_setflags alloc exec nowrite progbits
posix_spawnattr_setflags:
    movsx rsi, si
    test rsi, -16                 ; only the four supported flag bits
    jnz .invalid
    mov rax, [rdi]
    mov [rax + 16], si
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
