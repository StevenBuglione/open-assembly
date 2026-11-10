; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigsetjmp
; header: setjmp.h
; prototype: int sigsetjmp(sigjmp_buf env, int savemask)
; standard: POSIX.1-2024 XSH sigsetjmp
; deps: sigprocmask
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:sysv-jump-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Save the same calling context as setjmp and optionally save the calling thread signal mask.
; semantics: A nonzero savemask requests a mask snapshot. Record whether a valid snapshot was saved.
; semantics: Return zero when saving. A later valid siglongjmp can resume the caller with a nonzero result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigsetjmp:function
extern sigprocmask:function

section .text.sigsetjmp alloc exec nowrite progbits
sigsetjmp:
    movsxd rsi, esi
    mov [rdi], rbx
    mov [rdi + 8], rbp
    mov [rdi + 16], r12
    mov [rdi + 24], r13
    mov [rdi + 32], r14
    mov [rdi + 40], r15
    lea rax, [rsp + 8]
    mov [rdi + 48], rax
    mov rax, [rsp]
    mov [rdi + 56], rax
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    mov qword [rbx + 64], 0      ; flag and padding
    test esi, esi
    jz .done
    mov edi, 2                    ; SIG_SETMASK query with null input
    xor esi, esi
    lea rdx, [rbx + 72]
    call sigprocmask
    test eax, eax
    jnz .done
    mov dword [rbx + 64], 1
.done:
    add rsp, 8
    pop rbx
    pop rbp
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
