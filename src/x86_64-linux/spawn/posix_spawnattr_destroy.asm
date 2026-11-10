; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_destroy
; header: spawn.h
; prototype: int posix_spawnattr_destroy(posix_spawnattr_t *attr)
; standard: POSIX.1-2024 XSH posix_spawnattr_destroy
; deps: free
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release the storage of an initialized attribute object.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_destroy:function
extern free:function

section .text.posix_spawnattr_destroy alloc exec nowrite progbits
posix_spawnattr_destroy:
    push rbp
    mov rbp, rsp
    mov rax, [rdi]
    mov qword [rdi], 0
    mov qword [rdi + 8], 0
    mov rdi, rax
    call free
    xor eax, eax
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
