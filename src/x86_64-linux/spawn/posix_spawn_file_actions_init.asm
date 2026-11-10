; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawn_file_actions_init
; header: spawn.h
; prototype: int posix_spawn_file_actions_init(posix_spawn_file_actions_t *actions)
; standard: POSIX.1-2024 XSH posix_spawn_file_actions_init
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize an empty ordered action object in caller storage.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawn_file_actions_init:function

section .text.posix_spawn_file_actions_init alloc exec nowrite progbits
posix_spawn_file_actions_init:
    mov qword [rdi], 0
    mov qword [rdi + 8], 0
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
