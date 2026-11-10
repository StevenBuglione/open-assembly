; Read a nameserver and optional search configuration from resolv.conf.
; RDI resolver context, RSI sockaddr[32], RDX null or search block[1816].
; Return sockaddr length. Search block holds u32 count/ndots and six names.
bits 64
default rel

global __al_dns_config:function
extern __al_dns_build:function
extern __al_dns_config_server:function
extern __al_dns_option:function
extern __al_gai_line:function
extern __al_gai_word:function
extern fclose:function
extern fopen:function
extern memcpy:function
extern strcmp:function
extern strlen:function

section .text.__al_dns_config alloc exec nowrite progbits
__al_dns_config:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov rbx, rdi
    mov r13, rsi
    mov r15, rdx
    xor r14d, r14d              ; no nameserver yet
    mov qword [rsp], 256
    mov qword [r13], 0
    mov qword [r13 + 8], 0
    mov qword [r13 + 16], 0
    mov qword [r13 + 24], 0
    lea rax, [rbx + 832]        ; alternate bank for reverse
    test r15, r15
    jz .server_bank
    mov dword [r15], 0
    mov dword [r15 + 4], 1
    lea rax, [r15 + 1544]       ; alternate bank for forward
.server_bank:
    mov [rsp + 32], rax
    mov dword [rax], 0
    mov dword [rax + 112], 2
    mov dword [rax + 116], 1
    mov dword [rax + 120], 0
    lea rdi, [rel resolv_path]
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .default_server
    mov r12, rax

.read_line:
    cmp qword [rsp], 0
    je .close
    dec qword [rsp]
    mov rdi, r12
    lea rsi, [rbx + 1088]
    call __al_gai_line
    test rax, rax
    jz .close
    mov [rbx + 40], rax
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov [rsp + 8], rax
    mov rdi, rax
    lea rsi, [rel nameserver]
    call strcmp
    test eax, eax
    jz .server_word

.search_directives:
    mov rdi, [rsp + 8]
    lea rsi, [rel options]
    call strcmp
    test eax, eax
    jz .option_word
    test r15, r15
    jz .read_line
    mov rdi, [rsp + 8]
    lea rsi, [rel search]
    call strcmp
    test eax, eax
    jz .search
    mov rdi, [rsp + 8]
    lea rsi, [rel domain]
    call strcmp
    test eax, eax
    jz .domain
    jmp .read_line

.server_word:
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov rdi, rax
    mov rsi, r13
    mov rdx, [rsp + 32]
    mov ecx, r14d
    call __al_dns_config_server
    mov r14d, eax
    jmp .read_line

.search:
    mov dword [rsp + 16], 6
    jmp .new_suffixes
.domain:
    mov dword [rsp + 16], 1
.new_suffixes:
    mov dword [r15], 0
.suffix_word:
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov [rsp + 8], rax
    mov rdi, rax
    mov esi, 1
    xor edx, edx
    xor ecx, ecx               ; measure without writing a wire question
    mov r8d, 272
    call __al_dns_build
    cmp rax, 17                ; invalid or root-only suffix
    jbe .skip_suffix
    mov rdi, [rsp + 8]
    call strlen
    mov rsi, [rsp + 8]
    cmp byte [rsi + rax - 1], 46
    jne .copy_suffix
    dec rax
.copy_suffix:
    mov [rsp + 24], rax
    mov edi, [r15]
    shl edi, 8
    lea rdi, [r15 + rdi + 8]
    mov rdx, rax
    call memcpy
    mov rcx, [rsp + 24]
    mov byte [rax + rcx], 0
    inc dword [r15]
    mov eax, [r15]
    cmp eax, [rsp + 16]
    jb .suffix_word
    jmp .read_line
.skip_suffix:
    cmp dword [rsp + 16], 1
    je .read_line
    jmp .suffix_word

.option_word:
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov rdi, rax
    mov rsi, r15
    mov rdx, [rsp + 32]
    call __al_dns_option
    jmp .option_word

.close:
    mov rdi, r12
    call fclose
    test r14d, r14d
    jnz .ready
.default_server:
    mov word [r13], 2
    mov dword [r13 + 4], 0x0100007f
    mov r14d, 16
.ready:
    mov word [r13 + 2], 0x3500
    mov eax, r14d
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_dns_config alloc noexec nowrite progbits
resolv_path: db "/etc/resolv.conf", 0
read_mode: db "r", 0
nameserver: db "nameserver", 0
search: db "search", 0
domain: db "domain", 0
options: db "options", 0

section .note.GNU-stack noalloc noexec nowrite progbits
