; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wctomb
; header: stdlib.h
; prototype: int wctomb(char *s, wchar_t wc)
; standard: C17 7.22.7.3
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Encode one representable wide character. A null destination resets the conversion state and returns zero.
; semantics: Return minus one and set EILSEQ on invalid input. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wctomb:function
extern __al_mbstate_default:function
extern __al_mb_encode:function

section .text.wctomb alloc exec nowrite progbits
wctomb:
    movsxd rsi, esi
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12d, esi
    mov edi, 11
    call __al_mbstate_default
    mov qword [rax], 0
    mov rdx, rax
    xor eax, eax
    test rbx, rbx
    jz .done
    mov rdi, rbx
    mov esi, r12d
    call __al_mb_encode
.done:
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
