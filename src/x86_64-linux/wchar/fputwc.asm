; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fputwc
; header: wchar.h
; prototype: wint_t fputwc(wchar_t character, FILE *stream)
; standard: C17 7.29.3.3
; deps: -
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Encode and write a wide character using the stream encoding. Return the character or WEOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fputwc:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_orient:function
extern __al_stream_putwc:function

section .text.fputwc alloc exec nowrite progbits
fputwc:
    movsxd rdi, edi
    push rbx
    push r12
    push r13
    mov rbx, rsi
    mov r12d, edi
    mov r13d, -1                ; WEOF
    mov rdi, rbx
    call __al_stream_lock
    mov rdi, rbx
    mov esi, 1
    call __al_stream_orient
    test eax, eax
    jle .unlock
    mov rdi, rbx
    mov esi, r12d
    call __al_stream_putwc
    mov r13d, eax
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
