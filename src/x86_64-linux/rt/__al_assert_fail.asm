; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __al_assert_fail
; header: assert.h
; prototype: _Noreturn void __al_assert_fail(const char *expression, const char *file, unsigned int line, const char *function)
; standard: Runtime ABI __al_assert_fail
; deps: abort, strlen
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:c17-assert, reference:freestanding-abort
; provenance: original
; narrow_args: edx:u32
; variadic: false
; noreturn: true
; semantics: Report the failed assertion expression, file, line, and C function on standard error.
; semantics: Use the fatal raw diagnostic path without acquiring a stdio lock.
; semantics: Invoke abort after the diagnostic. Never return.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __al_assert_fail:function
extern __al_diagnostic:function
extern strlen:function
extern abort:function

section .text.__al_assert_fail alloc exec nowrite progbits
__al_assert_fail:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    mov r15, rcx

    lea rdi, [rel prefix]
    mov esi, 18
    call __al_diagnostic
    mov rdi, r12
    call strlen
    mov rdi, r12
    mov rsi, rax
    call __al_diagnostic
    lea rdi, [rel at_file]
    mov esi, 4
    call __al_diagnostic
    mov rdi, r13
    call strlen
    mov rdi, r13
    mov rsi, rax
    call __al_diagnostic
    lea rdi, [rel colon]
    mov esi, 1
    call __al_diagnostic

    mov r13d, 1000000000
    xor ebx, ebx                  ; a nonleading decimal digit has been emitted
.digit:
    mov rax, r14
    xor edx, edx
    div r13
    mov r14, rdx
    test eax, eax
    jnz .emit_digit
    test ebx, ebx
    jnz .emit_digit
    cmp r13d, 1
    jne .next_digit
.emit_digit:
    lea rdi, [rel decimal_digits]
    add rdi, rax
    mov esi, 1
    call __al_diagnostic
    mov ebx, 1
.next_digit:
    mov rax, r13
    xor edx, edx
    mov ecx, 10
    div rcx
    mov r13, rax
    test r13, r13
    jnz .digit

    lea rdi, [rel in_function]
    mov esi, 4
    call __al_diagnostic
    mov rdi, r15
    call strlen
    mov rdi, r15
    mov rsi, rax
    call __al_diagnostic
    lea rdi, [rel newline]
    mov esi, 1
    call __al_diagnostic
    call abort
    ud2

section .rodata.__al_assert_fail alloc noexec nowrite progbits
prefix: db "assertion failed: "
at_file: db " at "
colon: db ":"
in_function: db " in "
newline: db 10
decimal_digits: db "0123456789"

section .note.GNU-stack noalloc noexec nowrite progbits
