; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: inet_addr
; header: arpa/inet.h
; prototype: in_addr_t inet_addr(const char *source)
; standard: POSIX.1-2024 XSH inet_addr
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:posix-ipv4-address, diff:glibc, diff:musl, suite:libc-test
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert one to four IPv4 parts in decimal, octal or hexadecimal to network byte order.
; semantics: Require the complete spelling and range-check every part. Return INADDR_NONE on failure.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global inet_addr:function

section .text.inet_addr alloc exec nowrite progbits
inet_addr:
    xor r8d, r8d                ; preceding octets
    xor r9d, r9d                ; number of preceding octets
.part:
    xor r10d, r10d              ; value of the current part
    xor edx, edx                ; a digit has been consumed
    mov r11d, 10
    cmp byte [rdi], 48
    jne .digit
    mov r11d, 8
    mov edx, 1
    inc rdi
    movzx eax, byte [rdi]
    or eax, 32
    cmp eax, 120
    jne .digit
    mov r11d, 16
    xor edx, edx
    inc rdi
.digit:
    movzx eax, byte [rdi]
    lea ecx, [rax - 48]
    cmp ecx, 9
    jbe .digit_range
    or eax, 32
    lea ecx, [rax - 97]
    cmp ecx, 5
    ja .part_end
    add ecx, 10
.digit_range:
    cmp ecx, r11d
    jae .part_end
    imul r10, r11
    add r10, rcx
    mov eax, r10d
    cmp r10, rax
    jne .invalid
    mov edx, 1
    inc rdi
    jmp .digit
.part_end:
    test edx, edx
    jz .invalid
    cmp byte [rdi], 0
    je .last_part
    cmp byte [rdi], 46
    jne .invalid
    cmp r9d, 3
    jae .invalid
    cmp r10d, 255
    ja .invalid
    shl r8d, 8
    or r8d, r10d
    inc r9d
    inc rdi
    jmp .part
.last_part:
    mov ecx, 32
    mov edx, r9d
    shl edx, 3
    sub ecx, edx
    mov rax, r10
    shr rax, cl
    test rax, rax
    jnz .invalid
    shl r8, cl
    or r10d, r8d
    mov eax, r10d
    bswap eax
    ret
.invalid:
    mov eax, -1                 ; INADDR_NONE
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
