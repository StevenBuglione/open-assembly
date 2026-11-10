; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: freopen
; header: stdio.h
; prototype: FILE * freopen(const char *restrict path, const char *restrict mode, FILE *restrict stream)
; standard: C17 7.21.5.4
; deps: free, close
; errno: EINVAL, ENOENT, EACCES
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Close the existing association, then associate stream with the opened file and reset its buffering and indicators.
; semantics: Return stream on success. Return NULL on failure. A NULL pathname is unsupported and sets EINVAL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global freopen:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_close:function
extern __al_stdio_open:function
extern __al_stream_init:function
extern free:function

section .text.freopen alloc exec nowrite progbits
freopen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdx                 ; existing stream
    mov r12, rdi                 ; pathname
    mov r13, rsi                 ; mode
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov rdi, rbx
    mov esi, 1                   ; keep the stream object
    call __al_stream_close
    mov rdi, r12
    mov rsi, r13
    call __al_stdio_open
    test rax, rax
    js .failure
    mov rdi, rbx
    mov rsi, rax
    or rdx, [rbx + 8]           ; retain allocation ownership
    call __al_stream_init
    mov r14, rbx
    jmp .unlock
.failure:
    xor r14d, r14d
    test qword [rbx + 8], 8
    jz .unlock
    mov rdi, rbx
    call free
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov rax, r14
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
