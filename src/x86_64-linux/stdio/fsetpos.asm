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
; semantics: Restore the saved multibyte conversion state under the stream lock.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fsetpos:function
extern fseek:function
extern __al_stream_lock:function
extern __al_stream_unlock:function

section .text.fsetpos alloc exec nowrite progbits
fsetpos:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    call __al_stream_lock
    mov rdi, rbx
    mov rsi, [r12]
    xor edx, edx                ; SEEK_SET
    call fseek
    test eax, eax
    jnz .status
    mov rdx, [r12 + 8]
    mov [rbx + 136], rdx
.status:
    mov r12d, eax
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r12d
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
