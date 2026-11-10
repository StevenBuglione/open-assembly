; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mbrtoc16
; header: uchar.h
; prototype: size_t mbrtoc16(char16_t *restrict pc16, const char *restrict s, size_t n, mbstate_t *restrict ps)
; standard: C17 7.28.1.1
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Decode one scalar into UTF-16. Emit a queued low surrogate with (size_t)-3 and consume no input on that call.
; semantics: Clear the affected state on an encoding error. Preserve errno for successful or incomplete conversions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mbrtoc16:function
extern __al_mbstate_default:function
extern __al_mb_decode:function

section .text.mbrtoc16 alloc exec nowrite progbits
mbrtoc16:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx
    mov edi, 3
    test r15, r15
    jnz .input
    call __al_mbstate_default
    mov r15, rax
.input:
    test r13, r13
    jnz .decode
    xor r12d, r12d
    lea r13, [rel null_byte]
    mov r14d, 1
.decode:
    cmp dword [r15 + 4], 0x01000000
    jne .decode_scalar
    mov edx, [r15]
    mov qword [r15], 0
    mov rax, -3
    jmp .store
.decode_scalar:
    mov rdi, r13
    mov rsi, r14
    mov rdx, r15
    xor ecx, ecx                ; use current LC_CTYPE
    call __al_mb_decode
    test rax, rax
    js .done
    cmp edx, 0x10000
    jb .store
    sub edx, 0x10000
    mov ecx, edx
    and ecx, 0x3ff
    add ecx, 0xdc00
    mov [r15], ecx
    mov dword [r15 + 4], 0x01000000
    shr edx, 10
    add edx, 0xd800
.store:
    test r12, r12
    jz .done
    mov [r12], dx
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    ret

section .rodata alloc noexec nowrite progbits
null_byte: db 0

section .note.GNU-stack noalloc noexec nowrite progbits
