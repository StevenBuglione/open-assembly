; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: dirfd
; header: dirent.h
; prototype: int dirfd(DIR *dirp)
; standard: POSIX.1-2024 XSH dirfd
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the stream's borrowed descriptor without changing errno.
; semantics: The caller must leave ownership with the stream.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global dirfd:function

section .text.dirfd alloc exec nowrite progbits
dirfd:
    mov eax, [rdi + 4]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
