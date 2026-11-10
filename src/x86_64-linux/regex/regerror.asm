; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: regerror
; header: regex.h
; prototype: size_t regerror(int code, const regex_t *restrict expression, char *restrict buffer, size_t size)
; standard: POSIX.1-2024 XSH regerror
; deps: memcpy, strlen
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:posix-regex, diff:glibc, diff:musl, suite:libc-test
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the diagnostic size including the terminating null.
; semantics: If size is nonzero, copy as much diagnostic text as fits and terminate it.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global regerror:function
extern strlen:function
extern memcpy:function

section .text.regerror alloc exec nowrite progbits
regerror:
    push rbx
    push r12
    push r13
    push r14
    push r15
    movsxd r15, edi
    mov r12, rdx
    mov r13, rcx
    lea rbx, [rel messages]
    cmp r15, 13
    jbe .locate
    mov r15d, 14
.locate:
    mov rdi, rbx
    call strlen
    test r15, r15
    jz .found
    lea rbx, [rbx + rax + 1]
    dec r15
    jmp .locate
.found:
    lea r14, [rax + 1]
    test r13, r13
    jz .return
    dec r13
    cmp r13, rax
    jbe .copy
    mov r13, rax
.copy:
    mov rdi, r12
    mov rsi, rbx
    mov rdx, r13
    call memcpy
    mov byte [r12 + r13], 0
.return:
    mov rax, r14
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.regerror alloc noexec nowrite progbits
messages:
    db "Success", 0
    db "No match", 0
    db "Invalid regular expression", 0
    db "Invalid collating element", 0
    db "Invalid character class", 0
    db "Trailing backslash", 0
    db "Invalid back-reference", 0
    db "Unbalanced brackets", 0
    db "Unbalanced parentheses", 0
    db "Unbalanced braces", 0
    db "Invalid repetition bounds", 0
    db "Invalid character range", 0
    db "Insufficient memory", 0
    db "Invalid repetition operator", 0
    db "Unknown regular expression error", 0

section .note.GNU-stack noalloc noexec nowrite progbits
