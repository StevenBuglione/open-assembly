; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mbstowcs
; header: stdlib.h
; prototype: size_t mbstowcs(wchar_t *restrict dst, const char *restrict src, size_t len)
; standard: C17 7.22.8.1
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert the byte string in an initial state. Count without writing when dst is null. Exclude the terminating null from the result.
; semantics: Return minus one and set EILSEQ on invalid input. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mbstowcs:function
extern __al_mbstate_default:function
extern __al_mbs_convert:function

section .text.mbstowcs alloc exec nowrite progbits
mbstowcs:
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov edi, 12
    call __al_mbstate_default
    mov qword [rax], 0
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov rcx, rax
    call __al_mbs_convert
    pop r14
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
