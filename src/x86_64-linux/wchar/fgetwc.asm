; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fgetwc
; header: wchar.h
; prototype: wint_t fgetwc(FILE *stream)
; standard: C17 7.29.3.1
; deps: -
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read one wide character through the stream encoding and return it or WEOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fgetwc:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_orient:function
extern __al_stream_getwc:function

section .text.fgetwc alloc exec nowrite progbits
fgetwc:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12d, -1                ; WEOF
    call __al_stream_lock
    mov rdi, rbx
    mov esi, 1
    call __al_stream_orient
    test eax, eax
    jle .unlock
    mov rdi, rbx
    call __al_stream_getwc
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
