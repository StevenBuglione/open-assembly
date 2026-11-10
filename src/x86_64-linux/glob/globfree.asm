; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: globfree
; header: glob.h
; prototype: void globfree(glob_t *result)
; standard: POSIX.1-2024 XSH globfree
; deps: free
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:posix-pathname-expansion, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release all pathname strings and the vector from a glob result and clear its count and vector.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global globfree:function
extern free:function

section .text.globfree alloc exec nowrite progbits
globfree:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, [rbx + 8]
    test r12, r12
    jz .clear
    mov rax, [rbx + 16]
    lea r12, [r12 + rax * 8]
    mov r13, [rbx]
.paths:
    test r13, r13
    jz .vector
    mov rdi, [r12]
    call free
    add r12, 8
    dec r13
    jmp .paths
.vector:
    mov rdi, [rbx + 8]
    call free
.clear:
    mov qword [rbx], 0
    mov qword [rbx + 8], 0
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
