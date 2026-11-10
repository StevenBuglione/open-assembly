; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fputs
; header: stdio.h
; prototype: int fputs(const char *restrict s, FILE *restrict stream)
; standard: C17 7.21.7.4
; deps: strlen
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Write the string without its terminating NUL. Return a nonnegative value or EOF on error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fputs:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern strlen:function
extern __al_stream_write:function

section .text.fputs alloc exec nowrite progbits
fputs:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rsi
    mov r12, rdi
    mov rdi, rbx
    call __al_stream_lock
    mov rdi, r12
    call strlen
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call __al_stream_write
    xor r12d, r12d
    test rdx, rdx
    jz .unlock
    mov r12d, -1
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
