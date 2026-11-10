; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fwide
; header: wchar.h
; prototype: int fwide(FILE *stream, int mode)
; standard: C17 7.29.3.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Query stream orientation, establishing the sign of mode only while unoriented.
; semantics: Capture the LC_CTYPE encoding when establishing wide orientation.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fwide:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_orient:function

section .text.fwide alloc exec nowrite progbits
fwide:
    movsxd rsi, esi
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    call __al_stream_lock
    mov rdi, rbx
    mov esi, r12d
    call __al_stream_orient
    mov r12d, eax
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r12d
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
