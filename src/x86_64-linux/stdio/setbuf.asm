; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: setbuf
; header: stdio.h
; prototype: void setbuf(FILE *restrict stream, char *restrict buffer)
; standard: C17 7.21.5.5
; deps: setvbuf
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Select full buffering with BUFSIZ caller bytes, or unbuffered mode if buffer is NULL.
; semantics: Call before other stream operations.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global setbuf:function
extern setvbuf:function

section .text.setbuf alloc exec nowrite progbits
setbuf:
    push rbp
    mov rbp, rsp
    xor edx, edx                  ; _IOFBF
    mov ecx, 4096
    test rsi, rsi
    jnz .configure
    mov edx, 2                    ; _IONBF
    xor ecx, ecx
.configure:
    call setvbuf
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
