; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: http_is_token_byte
; header: http.h
; prototype: unsigned int http_is_token_byte(unsigned char byte)
; standard: Extension ABI http
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-http-model
; provenance: original
; narrow_args: dil:u8
; variadic: false
; semantics: Return one for an RFC 9110 token character byte and zero otherwise.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global http_is_token_byte:function

section .text.http_is_token_byte alloc exec nowrite progbits
http_is_token_byte:
    movzx edi, dil
    cmp edi, 128
    jae .invalid
    mov ecx, edi
    and ecx, 7
    shr edi, 3
    lea rax, [rel token_bits]
    movzx eax, byte [rax + rdi]
    shr eax, cl
    and eax, 1
    ret
.invalid:
    xor eax, eax
    ret

section .rodata.http_is_token_byte alloc noexec nowrite progbits
token_bits:
    db 0, 0, 0, 0, 0xfa, 0x6c, 0xff, 0x03
    db 0xfe, 0xff, 0xff, 0xc7, 0xff, 0xff, 0xff, 0x57

section .note.GNU-stack noalloc noexec nowrite progbits
