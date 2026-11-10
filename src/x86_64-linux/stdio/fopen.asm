; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fopen
; header: stdio.h
; prototype: FILE * fopen(const char *restrict path, const char *restrict mode)
; standard: C17 7.21.5.3
; deps: malloc, free, close
; errno: EINVAL, ENOMEM, ENOENT, EACCES
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Open a byte stream with the selected C mode and return it, or return NULL on failure.
; semantics: Text and binary modes have the same byte behavior. New streams default to full buffering.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fopen:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stdio_open:function
extern __al_stream_init:function
extern __al_stdio_errno:function
extern malloc:function
extern close:function

section .text.fopen alloc exec nowrite progbits
fopen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    mov rsi, r12
    call __al_stdio_open
    test rax, rax
    js .failure
    mov r13, rax                 ; new descriptor
    mov r14, rdx                 ; access flags
    mov edi, 4272                ; FILE and its inline buffer
    call malloc
    test rax, rax
    jz .no_memory
    mov rbx, rax
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r14
    or edx, 8                    ; heap-owned stream
    call __al_stream_init
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov r13, rbx
    jmp .done
.no_memory:
    mov rdi, r13
    call close
    mov edi, 12                  ; preserve the allocation failure
    call __al_stdio_errno
.failure:
    xor r13d, r13d
.done:
    mov rax, r13
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
