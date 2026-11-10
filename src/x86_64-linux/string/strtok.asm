; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strtok
; header: string.h
; prototype: char *strtok(char *restrict s, const char *restrict delimiters)
; standard: C17 7.24.5.8
; deps: strspn, strcspn
; errno: -
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: A non-NULL s starts a new writable string, and a NULL s resumes the last scan.
; semantics: Skip runs of delimiters and return the next nonempty token, replacing a following delimiter with NUL.
; semantics: Delimiter bytes may change between calls. Return NULL when no token remains.
; semantics: The continuation is process-wide. The two strings must not overlap.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strtok:function
extern strspn:function
extern strcspn:function

section .text.strtok alloc exec nowrite progbits
strtok:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    test rdi, rdi
    jnz .scan
    mov rdi, [rel continuation]
    test rdi, rdi
    jz .exhausted
.scan:
    mov [rsp], rdi
    mov [rsp + 8], rsi
    call strspn
    add rax, [rsp]
    cmp byte [rax], 0
    je .exhausted

    mov [rsp + 16], rax           ; first byte of the token
    mov rdi, rax
    mov rsi, [rsp + 8]
    call strcspn
    add rax, [rsp + 16]
    xor edx, edx
    cmp byte [rax], 0
    je .save
    mov byte [rax], 0
    lea rdx, [rax + 1]
.save:
    mov [rel continuation], rdx
    mov rax, [rsp + 16]
    jmp .done
.exhausted:
    mov qword [rel continuation], 0
    xor eax, eax
.done:
    add rsp, 32
    pop rbp
    ret

section .bss.strtok alloc noexec write nobits align=8
continuation:
    resq 1

section .note.GNU-stack noalloc noexec nowrite progbits
