; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: asctime
; header: time.h
; prototype: char *asctime(const struct tm *timeptr)
; standard: C17 7.27.3.1
; deps: __errno_location, strftime
; errno: EINVAL, EOVERFLOW
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:c17-civil-text
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert a valid broken-down time to the fixed 25-character C17 representation and terminator.
; semantics: Use the same C date and time names in the supported C and C.UTF-8 locales.
; semantics: Return a pointer to static text storage. Reject years outside 1000 through 9999 with EOVERFLOW.
; semantics: Reject out-of-range rendered fields with EINVAL rather than publishing partial text.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global asctime:function
extern strftime:function
extern __errno_location:function

section .text.asctime alloc exec nowrite progbits
asctime:
    sub rsp, 8
    mov eax, [rdi + 20]            ; tm_year + 1900, biased to start at 1000
    add eax, 900
    cmp eax, 8999
    ja .overflow
    mov eax, [rdi + 12]            ; day of month
    dec eax
    cmp eax, 30
    ja .invalid
    mov rcx, rdi
    lea rdi, [rel result]
    mov esi, 26
    lea rdx, [rel format]
    call strftime
    cmp rax, 25
    jne .invalid
    lea rax, [rel result]
    jmp .done
.overflow:
    mov edi, 75                   ; EOVERFLOW
    jmp .error
.invalid:
    mov edi, 22                   ; EINVAL
.error:
    mov [rsp], edi
    call __errno_location
    mov edx, [rsp]
    mov [rax], edx
    xor eax, eax
.done:
    add rsp, 8
    ret

section .rodata.asctime alloc noexec nowrite progbits
format: db "%a %b %e %T %Y", 10, 0

section .bss.asctime alloc noexec write nobits
result: resb 26

section .note.GNU-stack noalloc noexec nowrite progbits
