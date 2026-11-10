; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ftello
; header: stdio.h
; prototype: off_t ftello(FILE *stream)
; standard: POSIX.1-2024 XSH ftello
; deps: ftell
; errno: EBADF, ESPIPE, EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:lua-posix-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the same signed LP64 stream position as ftell.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ftello:function
extern ftell:function

section .text.ftello alloc exec nowrite progbits
ftello:
    push rbp
    mov rbp, rsp
    call ftell
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
