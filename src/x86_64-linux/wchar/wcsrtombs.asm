; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsrtombs
; header: wchar.h
; prototype: size_t wcsrtombs(char *restrict dst, const wchar_t **restrict src, size_t len, mbstate_t *restrict ps)
; standard: C17 7.29.6.4.2
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert the null-terminated wide string to bytes without splitting a multibyte character. Count-only calls preserve both source pointer and state.
; semantics: Return minus one and set EILSEQ on invalid input. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsrtombs:function
extern __al_mbstate_default:function
extern __al_wcs_convert:function

section .text.wcsrtombs alloc exec nowrite progbits
wcsrtombs:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    test r14, r14
    jnz .state_ready
    mov edi, 8
    call __al_mbstate_default
    mov r14, rax
.state_ready:
    test rbx, rbx
    jnz .convert
    mov edi, 13
    call __al_mbstate_default
    mov r15, [r14]
    mov [rax], r15
    mov r14, rax
.convert:
    mov rdi, rbx
    mov rsi, [r12]
    mov rdx, r13
    mov rcx, r14
    call __al_wcs_convert
    test rbx, rbx
    jz .done
    mov [r12], rdx
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
