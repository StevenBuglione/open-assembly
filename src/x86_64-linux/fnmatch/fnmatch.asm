; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fnmatch
; header: fnmatch.h
; prototype: int fnmatch(const char *pattern, const char *string, int flags)
; standard: POSIX.1-2024 XSH fnmatch
; deps: iswctype, towlower, towupper, wctype
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:posix-pattern-matching, diff:glibc, diff:musl
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Match a shell pattern against the entire input under the selected pathname, escape, period and case-folding flags.
; semantics: Use C-locale byte units or C.UTF-8 scalar units and the current character classes.
; semantics: Return zero for a match or FNM_NOMATCH otherwise. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fnmatch:function
extern __al_locale_flags:data
extern __al_fnmatch_unit:function
extern __al_fnmatch_bracket:function

section .text.fnmatch alloc exec nowrite progbits
fnmatch:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi
    mov r12, rsi
    mov r13, rsi                ; beginning of input for FNM_PERIOD
    movsxd rdx, edx
    mov r14, rdx
    mov r15d, [rel __al_locale_flags]
    and r15d, 1                 ; active LC_CTYPE is UTF-8
    mov eax, r14d
    and eax, 16                 ; FNM_CASEFOLD / FNM_IGNORECASE
    shr eax, 3
    or r15d, eax
    mov qword [rsp], 0          ; pattern immediately after the most recent star
.next:
    movzx eax, byte [rbx]
    test eax, eax
    jz .end_pattern
    cmp eax, 42
    je .wildcard
    cmp eax, 63
    je .wildcard
    cmp eax, 91
    je .wildcard
    cmp byte [r12], 0
    je .retry
    cmp eax, 92
    jne .literal
    test r14d, 2                ; FNM_NOESCAPE
    jnz .literal
    cmp byte [rbx + 1], 0
    je .literal
    inc rbx
.literal:
    mov rdi, r12
    mov esi, r15d
    call __al_fnmatch_unit
    mov [rsp + 16], edx          ; width of the current input unit
    mov [rsp + 20], eax
    mov rdi, rbx
    mov esi, r15d
    call __al_fnmatch_unit
    cmp eax, [rsp + 20]
    jne .retry
    add rbx, rdx
    jmp .consume
.wildcard:
    test r14d, 4                ; FNM_PERIOD
    jz .wild_token
    cmp byte [r12], 46
    jne .wild_token
    cmp r12, r13
    je .retry
    test r14d, 1                ; FNM_PATHNAME
    jz .wild_token
    cmp byte [r12 - 1], 47
    je .retry
.wild_token:
    cmp eax, 42
    je .star
    cmp byte [r12], 0
    je .retry
    test r14d, 1                ; FNM_PATHNAME
    jz .decode_wild
    cmp byte [r12], 47
    je .retry
.decode_wild:
    mov rdi, r12
    mov esi, r15d
    call __al_fnmatch_unit
    mov [rsp + 16], edx
    cmp byte [rbx], 63
    je .single_byte_token
    mov [rsp + 20], eax
    mov rdi, rbx
    mov esi, eax
    mov edx, r14d
    mov r8d, ecx                ; preserve original scalar for character classes
    mov ecx, r15d
    call __al_fnmatch_bracket
    test rax, rax
    jz .unclosed_bracket
    test edx, edx
    jz .retry
    mov rbx, rax
    jmp .consume
.unclosed_bracket:
    test edx, edx
    jnz .retry
    cmp dword [rsp + 20], 91
    jne .retry
.single_byte_token:
    inc rbx
.consume:
    mov eax, [rsp + 16]
    add r12, rax
    jmp .next
.star:
    inc rbx
    cmp byte [rbx], 42
    je .star
    mov [rsp], rbx
    mov [rsp + 8], r12
    jmp .next
.end_pattern:
    cmp byte [r12], 0
    je .match
.retry:
    mov rbx, [rsp]
    test rbx, rbx
    jz .no_match
    mov r12, [rsp + 8]
    cmp byte [r12], 0
    je .no_match
    test r14d, 1                ; FNM_PATHNAME
    jz .advance_star
    cmp byte [r12], 47
    je .no_match
.advance_star:
    mov rdi, r12
    mov esi, r15d
    and esi, 1                  ; advance by the encoding only
    call __al_fnmatch_unit
    movsxd rax, edx
    add r12, rax
    mov [rsp + 8], r12
    jmp .next
.match:
    xor eax, eax
    jmp .return
.no_match:
    mov eax, 1                 ; FNM_NOMATCH
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
