; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: c16rtomb
; header: uchar.h
; prototype: size_t c16rtomb(char *restrict s, char16_t c16, mbstate_t *restrict ps)
; standard: C17 7.28.1.2
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: si:u16
; variadic: false
; semantics: Encode a UTF-16 code unit or a completed surrogate pair. Queue a high surrogate in C.UTF-8 and return zero without writing.
; semantics: Clear the affected state on an encoding error. Preserve errno for successful or incomplete conversions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global c16rtomb:function
extern __al_mbstate_default:function
extern __al_mb_encode:function
extern __al_mb_error:function
extern __al_locale_flags:data

section .text.c16rtomb alloc exec nowrite progbits
c16rtomb:
    movzx esi, si
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    test r14, r14
    jnz .destination
    mov edi, 5
    call __al_mbstate_default
    mov r14, rax
.destination:
    test r12, r12
    jnz .state
    xor r13d, r13d
.state:
    cmp dword [r14 + 4], 0
    je .initial
    cmp dword [r14 + 4], 0x02000000
    jne .error
    cmp r13d, 0xdc00
    jb .error
    cmp r13d, 0xdfff
    ja .error
    mov eax, [r14]
    shl eax, 10
    sub r13d, 0xdc00
    lea r13d, [rax + r13 + 0x10000]
    mov qword [r14], 0
    jmp .encode
.initial:
    cmp r13d, 0xd800
    jb .encode
    cmp r13d, 0xdbff
    ja .encode
    test dword [rel __al_locale_flags], 1
    jz .error
    sub r13d, 0xd800
    mov [r14], r13d
    mov dword [r14 + 4], 0x02000000
    xor eax, eax
    jmp .done
.encode:
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    call __al_mb_encode
    jmp .done
.error:
    mov rdi, r14
    call __al_mb_error
.done:
    pop r14
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
