; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsftime
; header: wchar.h
; prototype: size_t wcsftime(wchar_t *restrict dest, size_t size, const wchar_t *restrict format, const struct tm *restrict value)
; standard: C17 7.29.5.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-time-format
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Format a broken-down time using a wide format and wide output, preserving wide literals.
; semantics: Use the same C-locale fields, modifiers and ISO week calculation as strftime in both supported locales.
; semantics: Return the count excluding the terminating null, or zero for invalid format or inadequate capacity.
; semantics: For size zero, return zero without accessing the destination. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsftime:function
extern __al_strftime_render:function

section .text.wcsftime alloc exec nowrite progbits
wcsftime:
    test rsi, rsi
    jz .failure
    dec rsi
    mov rax, rsi
    shr rax, 62
    jnz .failure
    shl rsi, 2
    add rsi, rdi                ; reserved wide terminator address
    jc .failure
    push rbx
    mov rbx, rdi
    mov r8d, 3                  ; wide format and destination
    call __al_strftime_render
    test rax, rax
    jz .restore
    mov dword [rax], 0
    sub rax, rbx
    shr rax, 2
.restore:
    pop rbx
    ret
.failure:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
