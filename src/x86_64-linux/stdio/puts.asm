; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: puts
; header: stdio.h
; prototype: int puts(const char *s)
; standard: C17 7.21.7.9
; deps: strlen
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Write s without its terminator followed by a newline to stdout.
; semantics: Return nonnegative on success or EOF on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global puts:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern strlen:function
extern __al_stream_write:function
extern stdout:data

section .text.puts alloc exec nowrite progbits
puts:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, [rel stdout]
    mov r12, rdi
    mov rdi, rbx
    call __al_stream_lock
    mov rdi, r12
    call strlen
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call __al_stream_write
    test rdx, rdx
    jnz .result
    mov rdi, rbx
    lea rsi, [rel newline]
    mov edx, 1
    call __al_stream_write
.result:
    xor r12d, r12d
    test rdx, rdx
    jz .unlock
    mov r12d, -1
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.puts alloc noexec nowrite progbits
newline:
    db 10

section .note.GNU-stack noalloc noexec nowrite progbits
