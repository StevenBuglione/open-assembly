; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: regexec
; header: regex.h
; prototype: int regexec(const regex_t *restrict expression, const char *restrict string, size_t count, regmatch_t *restrict matches, int flags)
; standard: POSIX.1-2024 XSH regexec
; deps: calloc, free, iswctype, malloc, memcmp, memcpy, memset, realloc, strlen, towlower, towupper, wctype
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:posix-regex, diff:glibc, diff:musl, suite:libc-test
; provenance: original
; narrow_args: r8d:s32
; variadic: false
; semantics: Search a null-terminated string for the leftmost longest match.
; semantics: Report byte offsets and participating subexpressions unless REG_NOSUB or a zero match count suppresses reporting.
; semantics: Return zero, REG_NOMATCH, or a REG error.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global regexec:function
extern calloc:function
extern malloc:function
extern free:function
extern strlen:function
extern __al_regex_exec:function

section .text.regexec alloc exec nowrite progbits
regexec:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, [rdi + 8]
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx
    movsxd r8, r8d
    mov [rsp], r8d
    test r8d, -4               ; REG_NOTBOL and REG_NOTEOL
    jnz .bad_flags
    test r12, r12
    jz .bad_flags
    test dword [r12 + 40], 8   ; REG_NOSUB
    jz .context
    xor r14d, r14d
.context:
    mov edi, 1
    mov esi, 176
    call calloc
    test rax, rax
    jz .no_context
    mov rbx, rax
    mov [rbx], r12
    mov [rbx + 8], r13
    mov [rbx + 16], r14
    mov [rbx + 24], r15
    mov eax, [rsp]
    mov [rbx + 32], eax
    mov eax, [r12 + 44]
    mov [rbx + 36], eax
    mov [rbx + 40], r13
    xor ecx, ecx
    test r14, r14
    jnz .tags
    cmp dword [r12 + 48], 0    ; internal captures can be needed for backrefs
    je .state_size
.tags:
    mov rcx, [r12 + 24]
    inc rcx
    mov rax, rcx
    shr rax, 60
    jnz .no_space
    shl rcx, 4
.state_size:
    mov [rbx + 72], rcx
    mov rax, [r12 + 32]
    shl rax, 4
    add rax, rcx
    jc .no_space
    mov [rbx + 64], rax
    mov rdi, rax
    add rax, 24
    jc .no_space
    mov [rbx + 120], rax       ; visited record stride
    sub rax, 8
    mov [rbx + 112], rax       ; alternative record stride
    test rdi, rdi
    jnz .allocate_state
    mov edi, 1
.allocate_state:
    call malloc
    test rax, rax
    jz .no_space
    mov [rbx + 56], rax
    test r14, r14
    jz .seen_size
    mov rdi, [rbx + 72]
    call malloc
    test rax, rax
    jz .no_space
    mov [rbx + 80], rax
.seen_size:
    mov rdi, r13
    call strlen
    cmp rax, 65536
    jae .maximum_buckets
    mov rdx, [r12 + 16]
    cmp rdx, 65536
    jae .maximum_buckets
    add rax, rdx
    mov edi, 64
.buckets:
    cmp rdi, rax
    jae .allocate_buckets
    cmp rdi, 65536
    jae .allocate_buckets
    shl rdi, 1
    jmp .buckets
.maximum_buckets:
    mov edi, 65536
.allocate_buckets:
    lea rax, [rdi - 1]
    mov [rbx + 136], rax
    mov esi, 8
    call calloc
    test rax, rax
    jz .no_space
    mov [rbx + 128], rax
    mov rdi, rbx
    call __al_regex_exec
    test eax, eax
    jnz .cleanup
    test r14, r14
    jz .cleanup
    mov rsi, [rbx + 80]
    mov rcx, [rbx + 72]
    shr rcx, 4
.report:
    mov rax, -1
    mov rdx, -1
    test rcx, rcx
    jz .store
    mov rdx, [rsi + 8]
    cmp rdx, -1
    je .next_group
    mov rax, [rsi]
    sub rax, r13
    sub rdx, r13
.next_group:
    add rsi, 16
    dec rcx
.store:
    mov [r15], rax
    mov [r15 + 8], rdx
    add r15, 16
    dec r14
    jnz .report
    xor eax, eax
    jmp .cleanup
.no_space:
    mov eax, 12                ; REG_ESPACE
.cleanup:
    mov [rsp + 8], eax
    mov rdi, [rbx + 144]
    call free
    mov rdi, [rbx + 128]
    call free
    mov rdi, [rbx + 88]
    call free
    mov rdi, [rbx + 80]
    call free
    mov rdi, [rbx + 56]
    call free
    mov rdi, rbx
    call free
    mov eax, [rsp + 8]
    jmp .return
.no_context:
    mov eax, 12
    jmp .return
.bad_flags:
    mov eax, 2                 ; REG_BADPAT
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
