; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ungetwc
; header: wchar.h
; prototype: wint_t ungetwc(wint_t character, FILE *stream)
; standard: C17 7.29.3.10
; deps: -
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Push back one wide character and clear EOF on success. Return the character or WEOF.
; semantics: Reject WEOF and preserve any existing pushback on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ungetwc:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_orient:function
extern __al_stream_flush:function
extern __al_stdio_errno:function

section .text.ungetwc alloc exec nowrite progbits
ungetwc:
    mov edi, edi
    cmp edi, -1
    je .invalid_character
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rsi
    mov r12d, edi
    mov rdi, rbx
    call __al_stream_lock
    mov rdi, rbx
    mov esi, 1
    call __al_stream_orient
    test eax, eax
    jle .failure
    cmp qword [rbx], 0
    jl .closed
    test qword [rbx + 8], 1
    jz .closed
    cmp dword [rbx + 144], -1
    jne .failure
    cmp qword [rbx + 56], 2
    jne .push
    mov rdi, rbx
    call __al_stream_flush
    test eax, eax
    jnz .failure
.push:
    mov [rbx + 144], r12d
    mov qword [rbx + 56], 1
    and qword [rbx + 8], -17    ; clear EOF
    or qword [rbx + 8], 64      ; I/O has started
    jmp .unlock
.closed:
    mov edi, 9                  ; EBADF
    call __al_stdio_errno
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
.invalid_character:
    mov eax, -1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
