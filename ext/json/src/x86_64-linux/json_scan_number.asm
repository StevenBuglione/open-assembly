; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: json_scan_number
; header: json.h
; prototype: long json_scan_number(const unsigned char *data, size_t length, size_t offset)
; standard: Extension ABI json
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:json-token-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Scan a JSON decimal number without evaluating or rounding it.
; semantics: Return its exclusive end offset or a negative error without changing errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global json_scan_number:function

section .text.json_scan_number alloc exec nowrite progbits
json_scan_number:
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
    mov rax, rdx
    cmp rax, rsi
    je .syntax
    cmp byte [rdi+rax], 0x2d
    jne .integer_first
    inc rax
.integer_first:
    cmp rax, rsi
    je .syntax
    movzx ecx, byte [rdi+rax]
    sub ecx, 0x30
    cmp ecx, 9
    ja .syntax
    inc rax
    test ecx, ecx
    jnz .integer_tail
    cmp rax, rsi
    je .done
    movzx ecx, byte [rdi+rax]
    sub ecx, 0x30
    cmp ecx, 9
    jbe .syntax
    jmp .fraction

.integer_tail:
    cmp rax, rsi
    je .done
    movzx ecx, byte [rdi+rax]
    sub ecx, 0x30
    cmp ecx, 9
    ja .fraction
    inc rax
    jmp .integer_tail

.fraction:
    cmp byte [rdi+rax], 0x2e
    jne .exponent
    inc rax
    cmp rax, rsi
    je .syntax
    movzx ecx, byte [rdi+rax]
    sub ecx, 0x30
    cmp ecx, 9
    ja .syntax
.fraction_tail:
    inc rax
    cmp rax, rsi
    je .done
    movzx ecx, byte [rdi+rax]
    sub ecx, 0x30
    cmp ecx, 9
    jbe .fraction_tail

.exponent:
    movzx ecx, byte [rdi+rax]
    or ecx, 0x20
    cmp ecx, 0x65
    jne .done
    inc rax
    cmp rax, rsi
    je .syntax
    movzx ecx, byte [rdi+rax]
    cmp ecx, 0x2b
    je .exponent_sign
    cmp ecx, 0x2d
    jne .exponent_first
.exponent_sign:
    inc rax
.exponent_first:
    cmp rax, rsi
    je .syntax
    movzx ecx, byte [rdi+rax]
    sub ecx, 0x30
    cmp ecx, 9
    ja .syntax
.exponent_tail:
    inc rax
    cmp rax, rsi
    je .done
    movzx ecx, byte [rdi+rax]
    sub ecx, 0x30
    cmp ecx, 9
    jbe .exponent_tail
.done:
    ret

.invalid:
    mov rax, -22
    ret
.overflow:
    mov rax, -75
    ret
.syntax:
    mov rax, -84
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
