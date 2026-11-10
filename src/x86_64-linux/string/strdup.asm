; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strdup
; header: string.h
; prototype: char *strdup(const char *s)
; standard: POSIX.1-2024 XSH strdup
; deps: strlen, malloc, memcpy
; errno: ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Allocate and copy the complete NUL-terminated string to independent caller-owned storage.
; semantics: Return a null pointer and set ENOMEM on allocation failure.
; semantics: Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strdup:function
extern strlen:function
extern malloc:function
extern memcpy:function

section .text.strdup alloc exec nowrite progbits
strdup:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    call strlen
    lea r12, [rax + 1]
    mov rdi, r12
    call malloc
    test rax, rax
    jz .done
    mov rdi, rax
    mov rsi, rbx
    mov rdx, r12
    call memcpy
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
