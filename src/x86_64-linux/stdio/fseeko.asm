; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fseeko
; header: stdio.h
; prototype: int fseeko(FILE *stream, off_t offset, int whence)
; standard: POSIX.1-2024 XSH fseeko
; deps: fseek
; errno: EINVAL, ESPIPE, EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:lua-posix-abi
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Use the same byte stream positioning as fseek with a signed LP64 offset.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fseeko:function
extern fseek:function

section .text.fseeko alloc exec nowrite progbits
fseeko:
    push rbp
    mov rbp, rsp
    movsxd rdx, edx
    call fseek
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
