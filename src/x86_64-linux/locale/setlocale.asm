; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: setlocale
; header: locale.h
; prototype: char *setlocale(int category, const char *locale)
; standard: C17 7.11.1.1
; deps: getenv, strcmp
; errno: -
; mt_safe: false
; as_safe: false
; oracles: reference:c-locale, reference:locale-environment, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Query or select the C locale for a supported category. Accept the C and POSIX names and return C.
; semantics: For an empty name, consult LC_ALL, the category variable, and LANG in that order, ignoring empty values and defaulting to C.
; semantics: An invalid category or unsupported selection returns null without changing the locale or errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global setlocale:function
extern getenv:function
extern strcmp:function

section .text.setlocale alloc exec nowrite progbits
setlocale:
    movsxd rdi, edi
    cmp edi, 6
    ja .invalid
    test rsi, rsi
    jz .query

    push r12
    push r13
    push r14
    mov r12d, edi
    xor r13d, r13d
    mov r14, rsi
    cmp byte [r14], 0
    jne .check_name

    lea rdi, [rel all_name]
    call getenv
    test rax, rax
    jz .category
    cmp byte [rax], 0
    jne .resolved
.category:
    cmp r12d, 6
    jne .category_value
    xor r12d, r12d
    mov r13d, 1
.category_value:
    lea rax, [rel category_names]
    lea rdi, [r12 + r12*2]
    lea rdi, [rax + rdi*4]
    call getenv
    test rax, rax
    jz .language
    cmp byte [rax], 0
    jne .resolved
.language:
    lea rdi, [rel lang_name]
    call getenv
    test rax, rax
    jz .accepted
    cmp byte [rax], 0
    je .accepted
.resolved:
    mov r14, rax
.check_name:
    mov rdi, r14
    lea rsi, [rel c_name]
    call strcmp
    test eax, eax
    jz .accepted
    mov rdi, r14
    lea rsi, [rel posix_name]
    call strcmp
    test eax, eax
    jnz .rejected
.accepted:
    test r13d, r13d
    jz .success
    inc r12d
    cmp r12d, 6
    jb .category_value
.success:
    lea rax, [rel c_name]
    jmp .restore
.rejected:
    xor eax, eax
.restore:
    pop r14
    pop r13
    pop r12
    ret
.query:
    lea rax, [rel c_name]
    ret
.invalid:
    xor eax, eax
    ret

section .rodata.setlocale alloc noexec nowrite progbits align=8
category_names:
    db "LC_CTYPE", 0, 0, 0, 0
    db "LC_NUMERIC", 0, 0
    db "LC_TIME", 0, 0, 0, 0, 0
    db "LC_COLLATE", 0, 0
    db "LC_MONETARY", 0
    db "LC_MESSAGES", 0
c_name:
    db "C", 0
posix_name:
    db "POSIX", 0
all_name:
    db "LC_ALL", 0
lang_name:
    db "LANG", 0

section .note.GNU-stack noalloc noexec nowrite progbits
