; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fputc
; header: stdio.h
; prototype: int fputc(int c, FILE *stream)
; standard: C17 7.21.7.3
; deps: -
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write c converted to unsigned char and return that byte as int, or EOF on error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fputc:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_write:function

section .text.fputc alloc exec nowrite progbits
fputc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    movsxd r12, edi
    mov rbx, rsi
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    and r12d, 255
    mov [rbx + 80], r12b
    mov rdi, rbx
    lea rsi, [rbx + 80]
    mov edx, 1
    call __al_stream_write
    test rdx, rdx
    jz .unlock
    mov r12d, -1
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
