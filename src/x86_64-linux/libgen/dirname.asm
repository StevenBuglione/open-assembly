; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: dirname
; header: libgen.h
; prototype: char *dirname(char *path)
; standard: POSIX.1-2024 XSH dirname
; deps: strlen
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the directory component of a pathname after removing trailing slashes.
; semantics: A null or empty input and a slash-free name return the dot string.
; semantics: A leading run of slashes with no remaining directory component yields one slash.
; semantics: The result can point into the caller storage and the operation may modify path.
; semantics: The returned fallback strings have static storage. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global dirname:function
extern strlen:function

section .text.dirname alloc exec nowrite progbits
dirname:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    test rbx, rbx
    jz .dot
    call strlen
    test rax, rax
    jz .dot
.trim_end:
    cmp byte [rbx + rax - 1], 47
    jne .last_slash
    dec rax
    jnz .trim_end
    jmp .root
.last_slash:
    dec rax
    cmp byte [rbx + rax], 47
    je .trim_separator
    test rax, rax
    jnz .last_slash
    jmp .dot
.trim_separator:
    test rax, rax
    jz .root
    cmp byte [rbx + rax - 1], 47
    jne .component
    dec rax
    jmp .trim_separator
.component:
    mov byte [rbx + rax], 0
    mov rax, rbx
    jmp .done
.dot:
    lea rax, [rel dot]
    jmp .done
.root:
    lea rax, [rel root]
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .rodata.dirname alloc noexec nowrite progbits
dot:
    db '.', 0
root:
    db '/', 0

section .note.GNU-stack noalloc noexec nowrite progbits
