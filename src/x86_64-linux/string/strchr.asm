; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strchr
; header: string.h
; prototype: char *strchr(const char *s, int c)
; standard: C17 7.24.5.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Return the first position equal to c converted to char, or NULL when absent. The terminating NUL can match.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strchr:function

section .text.strchr alloc exec nowrite progbits
strchr:
    movsxd rsi, esi
.next:
    mov al, [rdi]
    cmp al, sil
    je .found
    test al, al
    jz .absent
    inc rdi
    jmp .next
.found:
    mov rax, rdi
    ret
.absent:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
