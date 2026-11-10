; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_getsigmask
; header: spawn.h
; prototype: int posix_spawnattr_getsigmask(const posix_spawnattr_t *restrict attr, sigset_t *restrict value)
; standard: POSIX.1-2024 XSH posix_spawnattr_getsigmask
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the selected child signal mask from an initialized attribute object through value.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_getsigmask:function
extern __al_sigset_publish:function

section .text.posix_spawnattr_getsigmask alloc exec nowrite progbits
posix_spawnattr_getsigmask:
    push rbp
    mov rbp, rsp
    mov rax, [rdi]
    mov rdi, rsi
    mov rsi, [rax]
    call __al_sigset_publish
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
