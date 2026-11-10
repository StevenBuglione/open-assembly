; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fputws
; header: wchar.h
; prototype: int fputws(const wchar_t *restrict string, FILE *restrict stream)
; standard: C17 7.29.3.4
; deps: -
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Write a wide string without the terminating null. Return zero on success or EOF on error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fputws:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_orient:function
extern __al_stream_putwc:function

section .text.fputws alloc exec nowrite progbits
fputws:
    push rbx
    push r12
    push r13
    mov rbx, rsi
    mov r12, rdi
    mov r13d, -1                ; EOF
    mov rdi, rbx
    call __al_stream_lock
    mov rdi, rbx
    mov esi, 1
    call __al_stream_orient
    test eax, eax
    jle .unlock
.write:
    mov esi, [r12]
    test esi, esi
    jz .success
    mov rdi, rbx
    call __al_stream_putwc
    cmp eax, -1
    je .unlock
    add r12, 4
    jmp .write
.success:
    xor r13d, r13d
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
