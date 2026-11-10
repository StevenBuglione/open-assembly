; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fseek
; header: stdio.h
; prototype: int fseek(FILE *stream, long offset, int whence)
; standard: C17 7.21.9.2
; deps: -
; errno: EINVAL, ESPIPE, EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Set the logical position relative to the specified origin. Flush pending output and discard input buffering on success.
; semantics: Clear EOF and pushback on success. Return zero on success or nonzero on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fseek:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_flush:function
extern __al_stdio_seek:function
extern __al_stdio_errno:function

section .text.fseek alloc exec nowrite progbits
fseek:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi                  ; offset
    movsxd r13, edx               ; origin
    mov r14d, -1
    mov rdi, rbx
    call __al_stream_lock
    cmp r13, 2
    ja .invalid
    cmp qword [rbx], 0
    jl .closed
    or qword [rbx + 8], 64
    cmp qword [rbx + 56], 2
    jne .logical_input
    mov rdi, rbx
    call __al_stream_flush
    test eax, eax
    jnz .unlock
    jmp .seek
.logical_input:
    cmp r13, 1                    ; SEEK_CUR must compensate for read-ahead
    jne .seek
    cmp qword [rbx + 56], 1
    jne .seek
    mov rax, [rbx + 48]
    sub rax, [rbx + 40]
    cmp qword [rbx + 72], -1
    je .relative
    inc rax
.relative:
    sub r12, rax
    jo .overflow
.seek:
    mov rdi, [rbx]
    mov rsi, r12
    mov rdx, r13
    call __al_stdio_seek
    test rax, rax
    js .unlock
    and qword [rbx + 8], -17
    mov qword [rbx + 40], 0
    mov qword [rbx + 48], 0
    mov qword [rbx + 56], 0
    mov qword [rbx + 72], -1
    xor r14d, r14d
    jmp .unlock
.invalid:
    mov edi, 22
    jmp .errno
.closed:
    mov edi, 9
    jmp .errno
.overflow:
    mov edi, 75
.errno:
    call __al_stdio_errno
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r14d
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
