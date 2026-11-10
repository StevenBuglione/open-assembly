; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fsetpos
; header: stdio.h
; prototype: int fsetpos(FILE *stream, const fpos_t *pos)
; standard: C17 7.21.9.3
; deps: fseek
; errno: EINVAL, ESPIPE
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Set the position previously saved by fgetpos and clear EOF and pushback on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fsetpos:function
extern fseek:function

section .text.fsetpos alloc exec nowrite progbits
fsetpos:
    push rbp
    mov rbp, rsp
    mov rsi, [rsi]
    xor edx, edx                  ; SEEK_SET
    call fseek
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
