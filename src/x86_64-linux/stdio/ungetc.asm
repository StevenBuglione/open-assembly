; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ungetc
; header: stdio.h
; prototype: int ungetc(int c, FILE *stream)
; standard: C17 7.21.7.10
; deps: -
; errno: EBADF
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Push back one byte for the next read and clear EOF. Return the pushed byte as int.
; semantics: EOF or a second pending byte fails with EOF and preserves the existing pushback.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ungetc:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_flush:function
extern __al_stdio_errno:function

section .text.ungetc alloc exec nowrite progbits
ungetc:
    movsxd rdi, edi
    cmp rdi, -1
    je .invalid_byte
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rsi
    mov r12, rdi
    and r12d, 255
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    cmp qword [rbx], 0
    jl .closed
    test qword [rbx + 8], 1
    jz .closed
    cmp qword [rbx + 72], -1
    jne .failure
    cmp qword [rbx + 56], 2
    jne .push
    mov rdi, rbx
    call __al_stream_flush
    test eax, eax
    jnz .failure
.push:
    mov [rbx + 72], r12
    mov qword [rbx + 56], 1
    and qword [rbx + 8], -17
    or qword [rbx + 8], 64
    jmp .unlock
.closed:
    mov edi, 9                    ; EBADF
    call __al_stdio_errno
.failure:
    mov r12d, -1
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret
.invalid_byte:
    mov eax, -1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
