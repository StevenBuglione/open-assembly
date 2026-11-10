; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: setvbuf
; header: stdio.h
; prototype: int setvbuf(FILE *restrict stream, char *restrict buffer, int mode, size_t size)
; standard: C17 7.21.5.6
; deps: malloc, free
; errno: EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Set full, line, or unbuffered mode before other stream operations.
; semantics: A supplied buffer stays caller-owned. Return zero on success or nonzero on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global setvbuf:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern malloc:function
extern free:function
extern __al_stdio_errno:function

section .text.setvbuf alloc exec nowrite progbits
setvbuf:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi                  ; optional caller buffer
    movsxd r13, edx               ; buffering mode
    mov r14, rcx                  ; requested capacity
    xor r15d, r15d                ; new buffer ownership flag
    mov rdi, rbx
    call __al_stream_lock
    cmp r13, 2
    ja .invalid
    cmp qword [rbx], 0
    jl .invalid
    test qword [rbx + 8], 64
    jnz .invalid
    cmp r13, 2
    jne .buffered
    xor r12d, r12d
    xor r14d, r14d
    jmp .install
.buffered:
    test r12, r12
    jz .managed
    test r14, r14
    jz .invalid
    jmp .install
.managed:
    test r14, r14
    jnz .capacity
    mov r14d, 4096
.capacity:
    cmp r14, 4096
    ja .allocate
    lea r12, [rbx + 128]
    jmp .install
.allocate:
    mov rdi, r14
    call malloc
    test rax, rax
    jz .failure
    mov r12, rax
    mov r15d, 128
.install:
    test qword [rbx + 8], 128
    jz .save
    mov rdi, [rbx + 24]
    cmp rdi, r12
    je .keep_owned
    call free
    jmp .save
.keep_owned:
    mov r15d, 128
.save:
    and qword [rbx + 8], -129
    or [rbx + 8], r15
    mov [rbx + 24], r12
    mov [rbx + 32], r14
    mov [rbx + 64], r13
    xor r15d, r15d
    jmp .unlock
.invalid:
    mov edi, 22                   ; EINVAL
    call __al_stdio_errno
.failure:
    mov r15d, -1
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r15d
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
