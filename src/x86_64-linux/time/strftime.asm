; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strftime
; header: time.h
; prototype: size_t strftime(char *restrict dest, size_t size, const char *restrict format, const struct tm *restrict value)
; standard: C17 7.27.3.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-time-format
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Format a broken-down time using the C locale and all C17 conversion specifiers.
; semantics: Accept the specified E and O modifiers with the C locale fallback. Use the ISO week-year for g, G, and V.
; semantics: Use at least four magnitude digits for full years and a nonnegative modulo 100 for two-digit years.
; semantics: Use the supplied UTC offset and abbreviation when available. An unknown zone produces no characters.
; semantics: Reserve space for the terminating null byte. Return the byte count excluding that byte, or zero if the result does not fit.
; semantics: For size zero, return zero without accessing the destination. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strftime:function
extern __al_strftime_render:function

section .text.strftime alloc exec nowrite progbits
strftime:
    test rsi, rsi
    jz .failure
    dec rsi
    add rsi, rdi                 ; reserved terminator address
    jc .failure
    push rbx
    mov rbx, rdi
    xor r8d, r8d                 ; ASCII format and destination
    call __al_strftime_render
    test rax, rax
    jz .restore
    mov byte [rax], 0
    sub rax, rbx
.restore:
    pop rbx
    ret
.failure:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
