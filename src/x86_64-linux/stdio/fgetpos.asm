; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fgetpos
; header: stdio.h
; prototype: int fgetpos(FILE *restrict stream, fpos_t *restrict pos)
; standard: C17 7.21.9.1
; deps: ftell
; errno: EBADF, ESPIPE
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Save the logical position of stream in pos. Return zero on success or nonzero on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fgetpos:function
extern ftell:function

section .text.fgetpos alloc exec nowrite progbits
fgetpos:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rsi
    call ftell
    test rax, rax
    js .failure
    mov [rbx], rax
    mov qword [rbx + 8], 0        ; reserved conversion state
    xor eax, eax
    jmp .done
.failure:
    mov eax, -1
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
