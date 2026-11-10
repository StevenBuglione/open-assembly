; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: setlocale
; header: locale.h
; prototype: char *setlocale(int category, const char *locale)
; standard: C17 7.11.1.1
; deps: getenv, strlen, strncmp
; errno: -
; mt_safe: false
; as_safe: false
; oracles: reference:c-locale, reference:locale-environment, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Query or select C or C.UTF-8 for one category or for every category. Accept POSIX and C.utf8 aliases.
; semantics: Return the canonical category name, or an LC_ALL assignment string that can restore a mixed selection.
; semantics: For an empty name, consult LC_ALL, the category variable, and LANG in that order, ignoring empty values and defaulting to C.
; semantics: An invalid category or unsupported selection returns null with the previous locale and errno intact.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global setlocale:function
global __al_locale_flags:data
global __al_setlocale_lock:data
extern getenv:function
extern strlen:function
extern strncmp:function
extern __al_locale_value:function
extern __al_lock:function
extern __al_unlock:function

section .text.setlocale alloc exec nowrite progbits
setlocale:
    movsxd rdi, edi
    cmp edi, 6
    ja .invalid
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov ebx, edi
    mov r12, rsi
    test r12, r12
    jz .query
    cmp byte [r12], 0
    jne .explicit_name

    lea rdi, [rel all_name]
    call getenv
    test rax, rax
    jz .environment
    cmp byte [rax], 0
    je .environment
    mov r12, rax
    jmp .explicit_name
.environment:
    mov r13d, ebx
    xor r14d, r14d
    cmp ebx, 6
    jne .environment_category
    xor r13d, r13d
.environment_category:
    lea rax, [rel category_names]
    lea rdi, [r13 + r13*2]
    lea rdi, [rax + rdi*4]
    call getenv
    test rax, rax
    jz .language
    cmp byte [rax], 0
    jne .environment_value
.language:
    lea rdi, [rel language_name]
    call getenv
    test rax, rax
    jz .default_value
    cmp byte [rax], 0
    je .default_value
.environment_value:
    mov r12, rax
    mov rdi, rax
    call strlen
    mov rdi, r12
    mov rsi, rax
    call __al_locale_value
    test eax, eax
    js .reject
    jmp .environment_result
.default_value:
    xor eax, eax
.environment_result:
    cmp ebx, 6
    jne .single_selection
    mov ecx, r13d
    shl eax, cl
    or r14d, eax
    inc r13d
    cmp r13d, 6
    jb .environment_category
    jmp .all_selection

.explicit_name:
    mov rdi, r12
    call strlen
    mov rdi, r12
    mov rsi, rax
    call __al_locale_value
    test eax, eax
    js .possibly_composite
    cmp ebx, 6
    jne .single_selection
    mov r14d, eax
    imul r14d, 63
    jmp .all_selection

.possibly_composite:
    cmp ebx, 6
    jne .reject
    xor r13d, r13d
    xor r14d, r14d
    mov r15, r12
.parse_category:
    lea rax, [rel category_names]
    lea rdi, [r13 + r13*2]
    lea r12, [rax + rdi*4]
    mov rdi, r12
    call strlen
    mov [rsp], rax
    mov rdi, r15
    mov rsi, r12
    mov rdx, rax
    call strncmp
    test eax, eax
    jnz .reject
    add r15, [rsp]
    cmp byte [r15], 0x3d          ; =
    jne .reject
    inc r15
    mov r12, r15
.parse_value:
    movzx eax, byte [r15]
    test eax, eax
    jz .value_end
    cmp eax, 0x3b                ; ;
    je .value_end
    inc r15
    jmp .parse_value
.value_end:
    mov rdi, r12
    mov rsi, r15
    sub rsi, r12
    call __al_locale_value
    test eax, eax
    js .reject
    mov ecx, r13d
    shl eax, cl
    or r14d, eax
    inc r13d
    cmp r13d, 6
    je .composite_end
    cmp byte [r15], 0x3b
    jne .reject
    inc r15
    jmp .parse_category
.composite_end:
    cmp byte [r15], 0
    jne .reject
    jmp .all_selection

.single_selection:
    mov r14d, eax
    lea rdi, [rel __al_setlocale_lock]
    call __al_lock
    mov eax, 1
    mov ecx, ebx
    shl eax, cl
    mov edx, eax
    not eax
    and eax, [rel __al_locale_flags]
    test r14d, r14d
    jz .commit
    or eax, edx
    jmp .commit
.all_selection:
    lea rdi, [rel __al_setlocale_lock]
    call __al_lock
    mov eax, r14d
.commit:
    mov [rel __al_locale_flags], eax
    jmp .report
.query:
    lea rdi, [rel __al_setlocale_lock]
    call __al_lock
    mov eax, [rel __al_locale_flags]
.report:
    cmp ebx, 6
    je .report_all
    mov ecx, ebx
    shr eax, cl
    and eax, 1
    jmp .report_one
.report_all:
    test eax, eax
    jz .report_one
    cmp eax, 63
    jne .report_mixed
.report_one:
    test eax, eax
    lea rax, [rel c_name]
    jz .unlock
    lea rax, [rel utf8_name]
    jmp .unlock
.report_mixed:
    mov r14d, eax
    xor r13d, r13d
    lea r15, [rel mixed_name]
.copy_category:
    lea rax, [rel category_names]
    lea rsi, [r13 + r13*2]
    lea rsi, [rax + rsi*4]
.copy_key:
    movzx eax, byte [rsi]
    test eax, eax
    jz .write_equals
    mov [r15], al
    inc r15
    inc rsi
    jmp .copy_key
.write_equals:
    mov byte [r15], 0x3d
    inc r15
    mov eax, r14d
    mov ecx, r13d
    shr eax, cl
    lea rsi, [rel c_name]
    test eax, 1
    jz .copy_name
    lea rsi, [rel utf8_name]
.copy_name:
    movzx eax, byte [rsi]
    test eax, eax
    jz .next_category
    mov [r15], al
    inc r15
    inc rsi
    jmp .copy_name
.next_category:
    inc r13d
    cmp r13d, 6
    je .end_name
    mov byte [r15], 0x3b
    inc r15
    jmp .copy_category
.end_name:
    mov byte [r15], 0
    lea rax, [rel mixed_name]
    jmp .unlock
.unlock:
    mov [rsp + 8], rax
    lea rdi, [rel __al_setlocale_lock]
    call __al_unlock
    mov rax, [rsp + 8]
    jmp .done
.reject:
    xor eax, eax
.done:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    xor eax, eax
    ret

section .rodata alloc noexec nowrite progbits
category_names:
    db "LC_CTYPE", 0, 0, 0, 0
    db "LC_NUMERIC", 0, 0
    db "LC_TIME", 0, 0, 0, 0, 0
    db "LC_COLLATE", 0, 0
    db "LC_MONETARY", 0
    db "LC_MESSAGES", 0
c_name: db "C", 0
utf8_name: db "C.UTF-8", 0
all_name: db "LC_ALL", 0
language_name: db "LANG", 0

section .bss alloc noexec write nobits
alignb 16
__al_locale_flags: resd 1
__al_setlocale_lock: resd 1
mixed_name: resb 128

section .note.GNU-stack noalloc noexec nowrite progbits
