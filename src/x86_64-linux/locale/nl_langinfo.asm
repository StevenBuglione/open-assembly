; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nl_langinfo
; header: langinfo.h
; prototype: char *nl_langinfo(nl_item item)
; standard: POSIX.1-2024 XSH nl_langinfo
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:locale-codeset, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the immutable CODESET name for the current LC_CTYPE locale.
; semantics: Return an immutable empty string for unsupported items. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global nl_langinfo:function
extern __al_locale_flags:data

section .text.nl_langinfo alloc exec nowrite progbits
nl_langinfo:
    movsxd rdi, edi
    lea rax, [rel empty]
    cmp edi, 14                 ; CODESET
    jne .return
    lea rax, [rel ascii]
    test dword [rel __al_locale_flags], 1
    jz .return
    lea rax, [rel utf8]
.return:
    ret

section .rodata.nl_langinfo alloc noexec nowrite progbits
empty: db 0
ascii: db "ANSI_X3.4-1968", 0
utf8: db "UTF-8", 0

section .note.GNU-stack noalloc noexec nowrite progbits
