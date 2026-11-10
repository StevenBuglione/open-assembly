; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: regfree
; header: regex.h
; prototype: void regfree(regex_t *expression)
; standard: POSIX.1-2024 XSH regfree
; deps: free
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:posix-regex, diff:glibc, diff:musl, suite:libc-test
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release the compiled program and clear the expression.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global regfree:function
extern free:function

section .text.regfree alloc exec nowrite progbits
regfree:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, [rbx + 8]
    test r12, r12
    jz .clear
    mov rdi, [r12]
    call free
    mov rdi, [r12 + 8]
    call free
    mov rdi, r12
    call free
.clear:
    mov qword [rbx], 0
    mov qword [rbx + 8], 0
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
