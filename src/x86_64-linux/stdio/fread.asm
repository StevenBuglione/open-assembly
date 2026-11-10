; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fread
; header: stdio.h
; prototype: size_t fread(void *restrict dest, size_t size, size_t count, FILE *restrict stream)
; standard: C17 7.21.8.1
; deps: -
; errno: EOVERFLOW, EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read up to count elements of size bytes and return the number of complete elements.
; semantics: Zero size or count touches no data. An unrepresentable byte total fails with EOVERFLOW.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fread:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_read:function
extern __al_stdio_errno:function

section .text.fread alloc exec nowrite progbits
fread:
    test rsi, rsi
    jz .empty
    test rdx, rdx
    jz .empty
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rcx                 ; stream
    mov r12, rsi                 ; element width
    mov r13, rdx                 ; element count
    mov r14, rdi                 ; data pointer
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov rax, -1
    xor edx, edx
    div r12
    cmp r13, rax
    ja .overflow
    imul r13, r12
    mov rdi, rbx
    mov rsi, r14
    mov rdx, r13
    call __al_stream_read
    xor edx, edx
    div r12                      ; count only complete elements
    mov r13, rax
    jmp .unlock
.overflow:
    or qword [rbx + 8], 32
    mov edi, 75                  ; EOVERFLOW
    call __al_stdio_errno
    xor r13d, r13d
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov rax, r13
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.empty:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
