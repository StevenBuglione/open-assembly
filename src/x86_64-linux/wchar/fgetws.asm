; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fgetws
; header: wchar.h
; prototype: wchar_t *fgetws(wchar_t *restrict string, int count, FILE *restrict stream)
; standard: C17 7.29.3.2
; deps: -
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Read at most count minus one wide characters, retaining a newline and terminating successful output.
; semantics: Return null for invalid count, an input error, or EOF before a character.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fgetws:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_orient:function
extern __al_stream_getwc:function

section .text.fgetws alloc exec nowrite progbits
fgetws:
    movsxd rsi, esi
    test rsi, rsi
    jle .no_buffer
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdx
    mov r12, rdi
    lea r13, [rsi - 1]          ; space before the terminal null
    xor r14d, r14d              ; units stored
    mov rdi, rbx
    call __al_stream_lock
    mov rdi, rbx
    mov esi, 1
    call __al_stream_orient
    test eax, eax
    jle .failure
    test r13, r13
    jz .terminate
.read:
    mov rdi, rbx
    call __al_stream_getwc
    cmp eax, -1
    je .stop
    mov [r12 + r14 * 4], eax
    inc r14
    cmp eax, 10
    je .terminate
    cmp r14, r13
    jb .read
    jmp .terminate
.stop:
    test edx, edx
    jnz .failure
    test r14, r14
    jnz .terminate
.failure:
    xor r12d, r12d
    jmp .unlock
.terminate:
    mov dword [r12 + r14 * 4], 0
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov rax, r12
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.no_buffer:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
