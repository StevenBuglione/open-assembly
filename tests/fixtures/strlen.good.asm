; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strlen
; header: string.h
; prototype: size_t strlen(const char *s)
; standard: C17 7.24.6.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-count
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Input points to readable bytes up to and including the first zero byte.
; semantics: Return the count of bytes preceding the first zero as size_t; a nonzero byte counts regardless of its high bit.
; semantics: Ignore bytes after the first zero. Do not write to the input or read across an inaccessible boundary for a valid string.
; semantics: Null pointers and strings without a readable terminating zero are outside the contract.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

section .text.strlen progbits alloc exec nowrite align=16
global strlen:function
strlen:
    xor eax, eax
.loop:
    cmp byte [rdi + rax], 0
    jbe .done
    inc rax
    jmp .loop
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
