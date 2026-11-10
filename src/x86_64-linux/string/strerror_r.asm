; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strerror_r
; header: string.h
; prototype: int strerror_r(int errnum, char *strerrbuf, size_t buflen)
; standard: POSIX.1-2024 XSH strerror_r
; deps: strerror
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:posix-error-message
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write the complete project error message and terminating NUL into the supplied buffer.
; semantics: Zero denotes no error. Unknown numbers produce the message Unknown error.
; semantics: Return zero on success or ERANGE if the whole message does not fit. An insufficient buffer remains unchanged.
; semantics: The returned error number does not modify errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strerror_r:function
extern strerror:function

section .text.strerror_r alloc exec nowrite progbits
strerror_r:
    test rdx, rdx
    jz .no_capacity
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    movsxd r13, edi
    mov rbx, rsi
    mov r12, rdx
    mov rdi, r13
    call strerror
    mov r14, rax
    test r13, r13
    jz .length_start
    xor edi, edi
    call strerror
    cmp r14, rax               ; the shared no-error/unknown table entry
    jne .length_start
    lea r14, [rel unknown]
.length_start:
    xor ecx, ecx
.length:
    cmp rcx, r12
    jae .short_buffer
    cmp byte [r14 + rcx], 0
    je .copy_start
    inc rcx
    jmp .length
.copy_start:
    xor edx, edx
.copy:
    mov al, [r14 + rdx]
    mov [rbx + rdx], al
    inc rdx
    cmp rdx, rcx
    jbe .copy
    xor eax, eax
    jmp .done
.short_buffer:
    mov eax, 34                ; ERANGE as the return value
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.no_capacity:
    mov eax, 34
    ret

section .rodata.strerror_r alloc noexec nowrite progbits
unknown: db "Unknown error", 0

section .note.GNU-stack noalloc noexec nowrite progbits
