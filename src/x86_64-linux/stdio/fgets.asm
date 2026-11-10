; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fgets
; header: stdio.h
; prototype: char * fgets(char *restrict dest, int n, FILE *restrict stream)
; standard: C17 7.21.7.2
; deps: -
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Read at most n-1 bytes, stopping after newline or at EOF, and append NUL.
; semantics: Return dest on success or NULL for error, nonpositive n, or EOF before any byte. n equal to 1 writes an empty string.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fgets:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_read:function

section .text.fgets alloc exec nowrite progbits
fgets:
    movsxd rsi, esi
    test rsi, rsi
    jle .missing
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdx                 ; stream
    mov r12, rdi                 ; destination
    lea r13, [rsi - 1]           ; bytes before the terminator
    xor r14d, r14d               ; bytes read
    mov rdi, rbx
    call __al_stream_lock
    cmp dword [rbx + 128], 1
    je .failure
    mov dword [rbx + 128], -1
    test r13, r13
    jz .terminate
.next:
    mov rdi, rbx
    lea rsi, [r12 + r14]
    mov edx, 1
    call __al_stream_read
    test rdx, rdx
    jnz .failure
    test rax, rax
    jz .end_of_file
    inc r14
    cmp byte [r12 + r14 - 1], 10
    je .terminate
    cmp r14, r13
    jb .next
    jmp .terminate
.end_of_file:
    test r14, r14
    jnz .terminate
.failure:
    xor r12d, r12d
    jmp .unlock
.terminate:
    mov byte [r12 + r14], 0
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov rax, r12
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.missing:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
