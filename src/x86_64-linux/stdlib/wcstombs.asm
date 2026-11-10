; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcstombs
; header: stdlib.h
; prototype: size_t wcstombs(char *restrict dst, const wchar_t *restrict src, size_t len)
; standard: C17 7.22.8.2
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert the wide string in an initial state and preserve character boundaries. Count without writing when dst is null.
; semantics: Return minus one and set EILSEQ on invalid input. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcstombs:function
extern __al_mbstate_default:function
extern __al_wcs_convert:function

section .text.wcstombs alloc exec nowrite progbits
wcstombs:
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov edi, 13
    call __al_mbstate_default
    mov qword [rax], 0
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov rcx, rax
    call __al_wcs_convert
    pop r14
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
