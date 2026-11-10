; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fgetc
; header: stdio.h
; prototype: int fgetc(FILE *stream)
; standard: C17 7.21.7.1
; deps: -
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read and return one byte as unsigned char converted to int, or EOF on end of file or error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fgetc:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_read:function

section .text.fgetc alloc exec nowrite progbits
fgetc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, -1
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov rdi, rbx
    lea rsi, [rbx + 80]          ; stream scratch byte
    mov edx, 1
    call __al_stream_read
    test rax, rax
    jz .unlock
    movzx r12d, byte [rbx + 80]
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
