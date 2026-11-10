; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: localeconv
; header: locale.h
; prototype: struct lconv *localeconv(void)
; standard: C17 7.11.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:c-locale, reference:x86-64-lconv, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the shared LP64 C-locale numeric and monetary formatting record.
; semantics: Use a period for the decimal point, empty strings for the remaining text fields, and CHAR_MAX for the unavailable numeric fields.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global localeconv:function
extern __al_lock:function
extern __al_unlock:function

section .text.localeconv alloc exec nowrite progbits
localeconv:
    push rbx
    lea rbx, [rel c_format]
    lea rdi, [rel locale_lock]
    call __al_lock
    cmp qword [rbx], 0
    jne .ready

    lea rax, [rel empty]
    mov ecx, 8
.empty_fields:
    mov [rbx + rcx], rax
    add ecx, 8
    cmp ecx, 80
    jb .empty_fields
    mov rax, 0x7f7f7f7f7f7f7f7f
    mov [rbx + 80], rax
    mov rax, 0x00007f7f7f7f7f7f
    mov [rbx + 88], rax
    lea rax, [rel decimal]
    mov [rbx], rax
.ready:
    lea rdi, [rel locale_lock]
    call __al_unlock
    mov rax, rbx
    pop rbx
    ret

section .bss.localeconv alloc noexec write nobits align=8
c_format:
    resb 96
locale_lock:
    resq 1

section .rodata.localeconv alloc noexec nowrite progbits
decimal:
    db ".", 0
empty:
    db 0

section .note.GNU-stack noalloc noexec nowrite progbits
