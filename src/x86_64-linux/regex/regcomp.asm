; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: regcomp
; header: regex.h
; prototype: int regcomp(regex_t *restrict expression, const char *restrict pattern, int flags)
; standard: POSIX.1-2024 XSH regcomp
; deps: calloc, free, iswctype, strdup, strlen, towlower, towupper, wctype
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:posix-regex, diff:glibc, diff:musl, suite:libc-test
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Compile a POSIX basic or extended regular expression with the requested flags.
; semantics: Publish the subexpression count and an owned program on success. Return a REG error on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global regcomp:function
extern __al_locale_flags:data
extern calloc:function
extern free:function
extern strdup:function
extern strlen:function
extern __al_regex_parse:function
extern __al_regex_emit:function

section .text.regcomp alloc exec nowrite progbits
regcomp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, rdi
    mov r13, rsi
    movsxd rdx, edx
    mov r14, rdx
    mov qword [r12], 0
    mov qword [r12 + 8], 0
    test r14d, -16
    jnz .bad_flags
    mov rdi, r13
    call strlen
    mov r15, rax
    shr rax, 62
    jnz .no_context
    mov edi, 1
    mov esi, 80
    call calloc
    test rax, rax
    jz .no_context
    mov rbx, rax
    mov [rbx + 40], r14d
    and r14d, 6                ; case and newline flags share the unit mode
    mov eax, [rel __al_locale_flags]
    and eax, 1
    or eax, r14d
    mov [rbx + 44], eax
    mov rdi, r13
    call strdup
    test rax, rax
    jz .no_space
    mov [rbx], rax
    lea rdi, [r15 * 2 + 1]      ; atoms and joining nodes
    mov esi, 32
    call calloc
    test rax, rax
    jz .no_space
    mov [rbx + 56], rax
    lea rdi, [r15 + 1]          ; maximum parser and emitter depth
    mov esi, 32
    call calloc
    test rax, rax
    jz .no_space
    mov [rbx + 72], rax
    mov rdi, rbx
    call __al_regex_parse
    test edx, edx
    jnz .parse_error
    mov rdi, rbx
    mov rsi, rax
    call __al_regex_emit
    test eax, eax
    jnz .cleanup_error
    mov rdi, [rbx + 72]
    call free
    mov rdi, [rbx + 56]
    call free
    mov qword [rbx + 72], 0
    mov qword [rbx + 56], 0
    mov rax, [rbx + 24]
    mov [r12], rax
    mov [r12 + 8], rbx
    xor eax, eax
    jmp .return
.parse_error:
    mov eax, edx
    jmp .cleanup_error
.no_space:
    mov eax, 12                ; REG_ESPACE
.cleanup_error:
    mov [rsp], eax
    mov rdi, [rbx + 72]
    call free
    mov rdi, [rbx + 56]
    call free
    mov rdi, [rbx + 8]
    call free
    mov rdi, [rbx]
    call free
    mov rdi, rbx
    call free
    mov eax, [rsp]
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
