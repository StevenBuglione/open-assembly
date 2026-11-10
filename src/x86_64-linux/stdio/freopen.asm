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
; semantics: A successful reassociation resets byte or wide orientation and conversion state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global freopen:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_close:function
extern __al_stdio_open:function
extern __al_stream_rebind:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_unlock_all:function
extern __al_stream_unpin:function

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
    mov rdi, rbx
    call __al_stream_lock
    mov rdi, rbx
    mov esi, 1                   ; keep the stream object
    call __al_stream_close
    mov rdi, r12
    mov rsi, r13
    call __al_stdio_open
    test rax, rax
    js .failure
    mov r12, rax                  ; replacement descriptor
    mov r13, rdx
    or r13, [rbx + 8]            ; retain allocation ownership
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call __al_stream_rebind
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov rdi, rbx
    call __al_stream_unlock
    mov r14, rbx
    jmp .done
.failure:
    mov rdi, rbx
    call __al_stream_unlock_all
    mov rdi, rbx
    mov esi, 1
    call __al_stream_unpin
    xor r14d, r14d
.done:
    mov rax, r14
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
