; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strrchr
; header: string.h
; prototype: char *strrchr(const char *s, int c)
; standard: C17 7.24.5.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Return the last position equal to c converted to char, or NULL when absent. The terminating NUL can match.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strrchr:function

section .text.strrchr alloc exec nowrite progbits
strrchr:
    movsxd rsi, esi
    xor eax, eax
.next:
    mov dl, [rdi]
    cmp dl, sil
    jne .check_end
    mov rax, rdi
.check_end:
    test dl, dl
    jz .done
    inc rdi
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
