; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_setpgroup
; header: spawn.h
; prototype: int posix_spawnattr_setpgroup(posix_spawnattr_t *restrict attr, pid_t value)
; standard: POSIX.1-2024 XSH posix_spawnattr_setpgroup
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Store the nonnegative target process group in an initialized attribute object.
; semantics: Reject an unsupported value with EINVAL and leave the stored field unchanged.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_setpgroup:function

section .text.posix_spawnattr_setpgroup alloc exec nowrite progbits
posix_spawnattr_setpgroup:
    movsxd rsi, esi
    test esi, esi
    js .invalid
    mov rax, [rdi]
    mov [rax + 20], esi
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
