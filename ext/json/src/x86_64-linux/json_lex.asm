; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: json_lex
; header: json.h
; prototype: int json_lex(const unsigned char *restrict data, size_t length, size_t offset, size_t *restrict record)
; standard: Extension ABI json
; deps: json_scan_string, json_scan_number
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:json-token-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Skip ASCII JSON whitespace and scan one lexical token or end of input.
; semantics: Write its kind and source offsets only on success and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global json_lex:function
extern json_scan_number:function
extern json_scan_string:function

section .text.json_lex alloc exec nowrite progbits
json_lex:
    test rcx, rcx
    jz .invalid
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
    mov rax, rcx
    add rax, 24
    jc .overflow

.skip_space:
    cmp rdx, rsi
    je .end
    movzx eax, byte [rdi+rdx]
    cmp eax, 0x20
    je .advance
    cmp eax, 9
    je .advance
    cmp eax, 10
    je .advance
    cmp eax, 13
    jne .token
.advance:
    inc rdx
    jmp .skip_space

.token:
    lea r8, [rdx+1]
    cmp eax, 0x22
    je .string
    cmp eax, 0x74
    je .true
    cmp eax, 0x66
    je .false
    cmp eax, 0x6e
    je .null
    mov r9d, 6
    cmp eax, 0x7b
    je .publish
    inc r9d
    cmp eax, 0x7d
    je .publish
    inc r9d
    cmp eax, 0x5b
    je .publish
    inc r9d
    cmp eax, 0x5d
    je .publish
    inc r9d
    cmp eax, 0x3a
    je .publish
    inc r9d
    cmp eax, 0x2c
    je .publish
    cmp eax, 0x2d
    je .number
    sub eax, 0x30
    cmp eax, 9
    ja .syntax

.number:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rcx
    mov r12, rdx
    call json_scan_number
    mov r9d, 2
    jmp .scan_result
.string:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rcx
    mov r12, rdx
    call json_scan_string
    mov r9d, 1
.scan_result:
    mov rcx, rbx
    mov rdx, r12
    add rsp, 8
    pop r12
    pop rbx
    test rax, rax
    js .return
    mov r8, rax
    jmp .publish

.true:
    mov rax, rsi
    sub rax, rdx
    cmp rax, 4
    jb .syntax
    cmp dword [rdi+rdx], 0x65757274 ; true
    jne .syntax
    mov r9d, 3
    lea r8, [rdx+4]
    jmp .publish
.false:
    mov rax, rsi
    sub rax, rdx
    cmp rax, 5
    jb .syntax
    cmp dword [rdi+rdx], 0x736c6166 ; fals
    jne .syntax
    cmp byte [rdi+rdx+4], 0x65
    jne .syntax
    mov r9d, 4
    lea r8, [rdx+5]
    jmp .publish
.null:
    mov rax, rsi
    sub rax, rdx
    cmp rax, 4
    jb .syntax
    cmp dword [rdi+rdx], 0x6c6c756e ; null
    jne .syntax
    mov r9d, 5
    lea r8, [rdx+4]
    jmp .publish
.end:
    mov r8, rdx
    xor r9d, r9d

.publish:
    mov [rcx], r9
    mov [rcx+8], rdx
    mov [rcx+16], r8
    xor eax, eax
.return:
    ret
.invalid:
    mov eax, -22
    ret
.overflow:
    mov eax, -75
    ret
.syntax:
    mov eax, -84
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
