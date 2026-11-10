; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: json_parse
; header: json.h
; prototype: long json_parse(const unsigned char *restrict data, size_t length, size_t *restrict workspace, size_t frame_capacity, size_t *restrict tokens, size_t token_capacity)
; standard: Extension ABI json
; deps: json_lex
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:json-token-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Validate one bounded JSON value with caller scratch frames.
; semantics: Return the count of preorder source tokens or a negative error while preserving errno.
; semantics: Preserve all output tokens on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global json_parse:function
extern json_lex:function

section .text.json_parse alloc exec nowrite progbits
json_parse:
    test rdx, rdx
    jz .invalid
    test rdi, rdi
    jnz .check_tokens
    test rsi, rsi
    jnz .invalid
.check_tokens:
    test r8, r8
    jnz .extent
    test r9, r9
    jnz .invalid

.extent:
    test rsi, rsi
    js .overflow
    mov rax, rdi
    add rax, rsi
    jc .overflow
    mov rax, rcx
    shr rax, 60
    jnz .overflow
    mov rax, rcx
    shl rax, 4
    add rax, 24
    jc .overflow
    add rax, rdx
    jc .overflow
    mov rax, r9
    shr rax, 59
    jnz .overflow
    mov rax, r9
    shl rax, 5
    add rax, r8
    jc .overflow

    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8

    ; Stack words hold offset, depth, count, token capacity and emit mode.
    mov [rsp+24], r9
    mov qword [rsp+32], 0
.new_pass:
    mov qword [rsp], 0
    mov qword [rsp+8], 0
    mov qword [rsp+16], 0
.next:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, [rsp]
    mov rcx, r13
    call json_lex
    test eax, eax
    js .lex_error
    mov rax, [r13]
    xor r10d, r10d
    xor r11d, r11d
    mov rcx, [rsp+8]
    test rcx, rcx
    jnz .frame
    cmp qword [rsp+16], 0
    je .value
    test rax, rax
    jnz .syntax
    jmp .finish

.frame:
    ; Workspace starts with the three lexer words, followed by state/index pairs.
    shl rcx, 4
    lea r11, [r13+rcx+8]
    mov rcx, [r11]
    cmp ecx, 3
    jbe .array
    cmp ecx, 4
    je .object_start
    cmp ecx, 5
    je .object_key
    cmp ecx, 6
    je .object_colon
    cmp ecx, 7
    je .object_value

.object_separator:
    cmp eax, 7
    je .close
    cmp eax, 11
    jne .syntax
    mov qword [r11], 5
    jmp .advance
.object_start:
    cmp eax, 7
    je .close
.object_key:
    cmp eax, 1
    jne .syntax
    mov qword [r11], 6
    jmp .emit
.object_colon:
    cmp eax, 10
    jne .syntax
    mov qword [r11], 7
    jmp .advance
.object_value:
    mov qword [r11], 8
    jmp .value

.array:
    cmp ecx, 2
    je .array_value
    cmp eax, 9
    je .close
    cmp ecx, 1
    je .array_value
    cmp eax, 11
    jne .syntax
    mov qword [r11], 2
    jmp .advance
.array_value:
    mov qword [r11], 3

.value:
    cmp eax, 6
    je .open_object
    cmp eax, 8
    je .open_array
    lea ecx, [rax-1]
    cmp ecx, 4
    ja .syntax
    jmp .emit
.open_object:
    mov r10d, 4
    jmp .check_depth
.open_array:
    mov r10d, 1
.check_depth:
    cmp [rsp+8], r14
    jae .no_space

.emit:
    mov rdx, [rsp+16]
    cmp qword [rsp+32], 0
    je .count
    mov r8, rdx
    shl r8, 5
    add r8, r15
    mov [r8], rax
    mov r9, [r13+8]
    mov [r8+8], r9
    mov r9, [r13+16]
    mov [r8+16], r9
    mov r9, -1
    test r11, r11
    jz .store_parent
    mov r9, [r11+8]
.store_parent:
    mov [r8+24], r9

.count:
    inc qword [rsp+16]
    test r10d, r10d
    jz .advance
    mov rcx, [rsp+8]
    shl rcx, 4
    lea r11, [r13+rcx+24]
    mov [r11], r10
    mov [r11+8], rdx
    inc qword [rsp+8]
    jmp .advance

.close:
    cmp qword [rsp+32], 0
    je .pop_frame
    mov rcx, [r11+8]
    shl rcx, 5
    mov rdx, [r13+16]
    mov [r15+rcx+16], rdx
.pop_frame:
    dec qword [rsp+8]
.advance:
    mov rax, [r13+16]
    mov [rsp], rax
    jmp .next

.finish:
    mov rax, [rsp+16]
    cmp qword [rsp+32], 0
    jne .return
    cmp rax, [rsp+24]
    ja .no_space
    mov qword [rsp+32], 1
    jmp .new_pass

.lex_error:
    movsxd rax, eax
    jmp .return
.syntax:
    mov rax, -84
    jmp .return
.no_space:
    mov rax, -28
.return:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov rax, -22
    ret
.overflow:
    mov rax, -75
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
