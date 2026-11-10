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
; semantics: Save the multibyte conversion state of a wide stream together with its logical position.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fgetpos:function
extern ftell:function
extern __al_stream_lock:function
extern __al_stream_unlock:function

section .text.fgetpos alloc exec nowrite progbits
fgetpos:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    call __al_stream_lock
    mov rdi, rbx
    call ftell
    test rax, rax
    js .failure
    mov [r12], rax
    mov rax, [rbx + 136]
    cmp dword [rbx + 148], -1
    je .save_state
    mov rax, [rbx + 168]         ; state at the logical, pre-lookahead offset
.save_state:
    mov [r12 + 8], rax
    xor r12d, r12d
    jmp .unlock
.failure:
    mov r12d, -1
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r12d
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
