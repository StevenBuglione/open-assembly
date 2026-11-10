; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcstok
; header: wchar.h
; prototype: wchar_t *wcstok(wchar_t *restrict s, const wchar_t *restrict separators, wchar_t **restrict context)
; standard: C17 7.29.4.5.7
; deps: wcscspn, wcsspn
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the next token and keep the continuation in the caller's context.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcstok:function
extern wcsspn:function
extern wcscspn:function

section .text.wcstok alloc exec nowrite progbits
wcstok:
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    test r12, r12
    jnz .skip
    mov r12, [r14]
    test r12, r12
    jz .end
.skip:
    mov rdi, r12
    mov rsi, r13
    call wcsspn
    lea r12, [r12 + rax*4]
    cmp dword [r12], 0
    je .end
    mov rdi, r12
    mov rsi, r13
    call wcscspn
    lea rax, [r12 + rax*4]
    xor edx, edx
    cmp dword [rax], 0
    je .continue
    mov dword [rax], 0
    lea rdx, [rax + 4]
.continue:
    mov [r14], rdx
    mov rax, r12
    jmp .done
.end:
    mov qword [r14], 0
    xor eax, eax
.done:
    pop r14
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
