; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: perror
; header: stdio.h
; prototype: void perror(const char *s)
; standard: C17 7.21.10.4
; deps: __errno_location, strerror, strlen
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Write the current C-locale errno message to stderr and append a newline.
; semantics: Precede the message with s and colon-space when s is nonempty.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global perror:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __errno_location:function
extern stderr:data
extern strlen:function
extern strerror:function
extern __al_stream_write:function

section .text.perror alloc exec nowrite progbits
perror:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    call __errno_location
    mov r13d, [rax]
    mov rbx, [rel stderr]
    mov rdi, rbx
    call __al_stream_lock
    test r12, r12
    jz .message
    mov rdi, r12
    call strlen
    test rax, rax
    jz .message
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call __al_stream_write
    test rdx, rdx
    jnz .unlock
    mov rdi, rbx
    lea rsi, [rel separator]
    mov edx, 2
    call __al_stream_write
    test rdx, rdx
    jnz .unlock
.message:
    mov edi, r13d
    call strerror
    mov r12, rax
    mov rdi, rax
    call strlen
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call __al_stream_write
    test rdx, rdx
    jnz .unlock
    mov rdi, rbx
    lea rsi, [rel newline]
    mov edx, 1
    call __al_stream_write
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.perror alloc noexec nowrite progbits
separator:
    db ": "
newline:
    db 10

section .note.GNU-stack noalloc noexec nowrite progbits
