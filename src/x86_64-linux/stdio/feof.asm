; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: feof
; header: stdio.h
; prototype: int feof(FILE *stream)
; standard: C17 7.21.10.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return nonzero if the EOF indicator is set, or zero otherwise.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global feof:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function

section .text.feof alloc exec nowrite progbits
feof:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov r12, [rbx + 8]
    and r12d, 16
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
