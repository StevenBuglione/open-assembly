; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: json_scan_string
; header: json.h
; prototype: long json_scan_string(const unsigned char *data, size_t length, size_t offset)
; standard: Extension ABI json
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:json-token-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Scan a quoted byte span using JSON escapes and strict RFC 3629 scalar UTF-8.
; semantics: Return its exclusive end offset or a negative error without changing errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global json_scan_string:function

section .text.json_scan_string alloc exec nowrite progbits
json_scan_string:
    cmp rdx, rsi
    ja .invalid
    test rdi, rdi
    jnz .extent
    test rsi, rsi
    jnz .invalid
.extent:
    test rsi, rsi
    js .overflow
    mov rax, rdi
    add rax, rsi
    jc .overflow
    cmp rdx, rsi
    je .syntax
    cmp byte [rdi+rdx], 0x22
    jne .syntax
    inc rdx

.next_byte:
    cmp rdx, rsi
    je .syntax
    movzx ecx, byte [rdi+rdx]
    inc rdx
    cmp ecx, 0x22
    je .done
    cmp ecx, 0x5c
    je .escape
    cmp ecx, 0x20
    jb .syntax
    cmp ecx, 0x80
    jb .next_byte

    ; The first continuation has tighter bounds at four UTF-8 edges.
    cmp ecx, 0xc2
    jb .syntax
    cmp ecx, 0xf4
    ja .syntax
    mov r8d, 1
    mov r9d, 0x80
    mov r10d, 0xbf
    cmp ecx, 0xe0
    jb .first_continuation
    inc r8d
    cmp ecx, 0xe0
    jne .check_ed
    mov r9d, 0xa0
    jmp .first_continuation
.check_ed:
    cmp ecx, 0xed
    jne .check_four
    mov r10d, 0x9f
    jmp .first_continuation
.check_four:
    cmp ecx, 0xf0
    jb .first_continuation
    inc r8d
    cmp ecx, 0xf0
    jne .check_f4
    mov r9d, 0x90
    jmp .first_continuation
.check_f4:
    cmp ecx, 0xf4
    jne .first_continuation
    mov r10d, 0x8f
.first_continuation:
    mov rax, rsi
    sub rax, rdx
    cmp rax, r8
    jb .syntax
    movzx ecx, byte [rdi+rdx]
    cmp ecx, r9d
    jb .syntax
    cmp ecx, r10d
    ja .syntax
    inc rdx
    dec r8d
    jz .next_byte
.more_continuations:
    movzx ecx, byte [rdi+rdx]
    sub ecx, 0x80
    cmp ecx, 0x3f
    ja .syntax
    inc rdx
    dec r8d
    jnz .more_continuations
    jmp .next_byte

.escape:
    cmp rdx, rsi
    je .syntax
    movzx ecx, byte [rdi+rdx]
    inc rdx
    cmp ecx, 0x22
    je .next_byte
    cmp ecx, 0x5c
    je .next_byte
    cmp ecx, 0x2f
    je .next_byte
    cmp ecx, 0x62
    je .next_byte
    cmp ecx, 0x66
    je .next_byte
    cmp ecx, 0x6e
    je .next_byte
    cmp ecx, 0x72
    je .next_byte
    cmp ecx, 0x74
    je .next_byte
    cmp ecx, 0x75
    jne .syntax
    xor r10d, r10d
.hex_unit:
    mov rax, rsi
    sub rax, rdx
    cmp rax, 4
    jb .syntax
    xor r8d, r8d
    mov r9d, 4
.hex_digit:
    movzx ecx, byte [rdi+rdx]
    lea eax, [rcx-0x30]
    cmp eax, 9
    jbe .hex_value
    or ecx, 0x20
    sub ecx, 0x61
    cmp ecx, 5
    ja .syntax
    lea eax, [rcx+10]
.hex_value:
    shl r8d, 4
    or r8d, eax
    inc rdx
    dec r9d
    jnz .hex_digit
    test r10d, r10d
    jnz .low_surrogate
    cmp r8d, 0xd800
    jb .next_byte
    cmp r8d, 0xdfff
    ja .next_byte
    cmp r8d, 0xdc00
    jae .syntax
    mov rax, rsi
    sub rax, rdx
    cmp rax, 2
    jb .syntax
    cmp word [rdi+rdx], 0x755c
    jne .syntax
    add rdx, 2
    mov r10d, 1
    jmp .hex_unit
.low_surrogate:
    sub r8d, 0xdc00
    cmp r8d, 0x3ff
    jbe .next_byte
.syntax:
    mov rax, -84
    ret
.done:
    mov rax, rdx
    ret
.invalid:
    mov rax, -22
    ret
.overflow:
    mov rax, -75
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
