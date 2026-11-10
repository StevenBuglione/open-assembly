; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: http_find_header_end
; header: http.h
; prototype: size_t http_find_header_end(const unsigned char *bytes, size_t length)
; standard: Extension ABI http
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-http-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the byte count through the first CRLF CRLF, or zero when it is absent.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global http_find_header_end:function

section .text.http_find_header_end alloc exec nowrite progbits
http_find_header_end:
    cmp rsi, 4
    jb .missing
    sub rsi, 3                  ; possible four-byte starts
    xor ecx, ecx
.next:
    cmp dword [rdi + rcx], 0x0a0d0a0d
    je .found
    inc rcx
    cmp rcx, rsi
    jb .next
.missing:
    xor eax, eax
    ret
.found:
    lea rax, [rcx + 4]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
