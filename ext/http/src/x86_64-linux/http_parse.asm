; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: http_parse
; header: http.h
; prototype: unsigned int http_parse(const unsigned char *bytes, size_t length)
; standard: Extension ABI http
; deps: http_find_header_end, http_is_token_byte
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-http-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Classify one bounded HTTP request head using the loopback origin-server grammar.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global http_parse:function
extern http_find_header_end:function
extern http_is_token_byte:function

section .text.http_parse alloc exec nowrite progbits
http_parse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                ; beginning of the header section
    mov r13, rsi
    cmp rsi, 8192
    jbe .find_end
    mov esi, 8192
.find_end:
    call http_find_header_end
    test rax, rax
    jnz .start_line
    cmp r13, 8192
    jb .return
    mov eax, 431
    jmp .return
.start_line:
    ; A nonzero finder result covers the first CRLF CRLF within the
    ; bounded span. The mandatory CRLF at r14-2 stops each byte scan.
    ; Version and field transitions consume at most through that CRLF
    ; and test the resulting cursor before starting another field.
    lea r14, [r12 + rax - 2]    ; CR of the terminal empty line
    mov rbx, r12
    xor r15d, r15d              ; GET, HEAD, root, HTTP/1.1, Host, length
.method_byte:
    movzx edi, byte [rbx]
    cmp edi, 32
    je .method_end
    call http_is_token_byte
    test eax, eax
    jz .invalid
    inc rbx
    jmp .method_byte
.method_end:
    mov rax, rbx
    sub rax, r12
    jz .invalid
    cmp rax, 3
    jne .check_head
    cmp dword [r12], 0x20544547 ; GET and its required space
    jne .target_start
    or r15d, 1
    jmp .target_start
.check_head:
    cmp rax, 4
    jne .target_start
    cmp dword [r12], 0x44414548 ; HEAD
    jne .target_start
    or r15d, 2
.target_start:
    inc rbx
    cmp byte [rbx], 47
    jne .invalid
    mov r13, rbx
.target_byte:
    movzx eax, byte [rbx]
    cmp eax, 32
    je .target_end
    jb .invalid
    cmp eax, 126
    ja .invalid
    cmp eax, 35
    je .invalid
    inc rbx
    jmp .target_byte
.target_end:
    mov rax, rbx
    sub rax, r13
    cmp rax, 1
    jne .version
    or r15d, 4
.version:
    inc rbx
    mov rax, r14
    sub rax, rbx
    cmp rax, 10
    jb .invalid
    cmp word [rbx + 8], 0x0a0d
    jne .invalid
    mov rax, [rbx]
    mov rcx, 0x302e312f50545448 ; HTTP/1.0
    cmp rax, rcx
    je .version_end
    mov rcx, 0x312e312f50545448 ; HTTP/1.1
    cmp rax, rcx
    jne .invalid
    or r15d, 8
.version_end:
    add rbx, 10
.field_start:
    cmp rbx, r14
    je .finished
    mov r13, rbx
.field_name_byte:
    movzx edi, byte [rbx]
    cmp edi, 58
    je .field_name_end
    call http_is_token_byte
    test eax, eax
    jz .invalid
    inc rbx
    jmp .field_name_byte
.field_name_end:
    mov rax, rbx
    sub rax, r13
    jz .invalid
    xor r8d, r8d
    cmp rax, 4
    je .match_host
    cmp rax, 14
    je .match_length
    cmp rax, 17
    jne .value_start
    mov rcx, 0x2020202020202020
    mov rax, [r13]
    or rax, rcx
    mov rdx, 0x726566736e617274 ; transfer
    cmp rax, rdx
    jne .value_start
    mov rax, [r13 + 8]
    or rax, rcx
    mov rdx, 0x6e69646f636e652d ; -encodin
    cmp rax, rdx
    jne .value_start
    movzx eax, byte [r13 + 16]
    or eax, 32
    cmp eax, 103                ; g
    je .invalid
    jmp .value_start
.match_host:
    mov eax, [r13]
    or eax, 0x20202020
    cmp eax, 0x74736f68         ; host
    jne .value_start
    test r15d, 16
    jnz .invalid
    or r15d, 16
    mov r8d, 1
    jmp .value_start
.match_length:
    mov rcx, 0x2020202020202020
    mov rax, [r13]
    or rax, rcx
    mov rdx, 0x2d746e65746e6f63 ; content-
    cmp rax, rdx
    jne .value_start
    mov eax, [r13 + 8]
    or eax, 0x20202020
    cmp eax, 0x676e656c         ; leng
    jne .value_start
    movzx eax, word [r13 + 12]
    or eax, 0x2020
    cmp eax, 0x6874             ; th
    jne .value_start
    test r15d, 32
    jnz .invalid
    or r15d, 32
    mov r8d, 2
.value_start:
    inc rbx
    mov r13, rbx
.value_byte:
    movzx eax, byte [rbx]
    cmp eax, 13
    je .value_end
    cmp eax, 9
    je .value_next
    cmp eax, 32
    jb .invalid
    cmp eax, 126
    ja .invalid
.value_next:
    inc rbx
    jmp .value_byte
.value_end:
    cmp byte [rbx + 1], 10      ; rbx is still before the terminal CR
    jne .invalid
    mov rdx, rbx
    add rbx, 2
    test r8d, r8d
    jz .field_start
.trim_left:
    cmp r13, rdx
    jae .invalid
    movzx eax, byte [r13]
    cmp eax, 32
    je .skip_left
    cmp eax, 9
    jne .trim_right
.skip_left:
    inc r13
    jmp .trim_left
.trim_right:
    movzx eax, byte [rdx - 1]
    cmp eax, 32
    je .skip_right
    cmp eax, 9
    jne .trimmed
.skip_right:
    dec rdx
    jmp .trim_right
.trimmed:
    cmp r8d, 1
    je .host_start
.zero_length:
    cmp byte [r13], 48
    jne .invalid
    inc r13
    cmp r13, rdx
    jb .zero_length
    jmp .field_start
.host_start:
    mov r12, r13
.host_byte:
    movzx eax, byte [r13]
    cmp eax, 58
    je .host_port
    cmp eax, 45
    je .host_next
    cmp eax, 46
    je .host_next
    lea ecx, [rax - 48]
    cmp ecx, 9
    jbe .host_next
    or eax, 32
    sub eax, 97
    cmp eax, 25
    ja .invalid
.host_next:
    inc r13
    cmp r13, rdx
    jb .host_byte
    jmp .field_start
.host_port:
    cmp r13, r12
    je .invalid
    inc r13
    mov rax, rdx
    sub rax, r13
    dec rax
    cmp rax, 4                 ; one through five digits
    ja .invalid
    xor ecx, ecx
.port_digit:
    movzx eax, byte [r13]
    sub eax, 48
    cmp eax, 9
    ja .invalid
    imul ecx, 10
    add ecx, eax
    inc r13
    cmp r13, rdx
    jb .port_digit
    cmp ecx, 65535
    ja .invalid
    jmp .field_start
.finished:
    test r15d, 8
    jz .select_status
    test r15d, 16
    jz .invalid
.select_status:
    mov eax, 405
    test r15d, 3
    jz .return
    mov eax, 404
    test r15d, 4
    jz .head_flag
    mov eax, 200
.head_flag:
    test r15d, 2
    jz .return
    or eax, 65536
    jmp .return
.invalid:
    mov eax, 400
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
