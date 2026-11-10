; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: slice_take
; header: slice.h
; prototype: int slice_take(const unsigned char **restrict cursor, size_t *restrict available, size_t length, const unsigned char **restrict result)
; standard: Extension ABI slice
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-slice-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Publish the current cursor and advance it by length while reducing available.
; semantics: Return -EINVAL for invalid metadata, -EOVERFLOW for a wrapping span, or -ERANGE for insufficient bytes.
; semantics: Read no slice bytes and preserve metadata, result and errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global slice_take:function

section .text.slice_take alloc exec nowrite progbits
slice_take:
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jz .invalid
    test rcx, rcx
    jz .invalid
    mov r8, [rdi]
    mov r9, [rsi]
    test r8, r8
    jnz .extent
    test r9, r9
    jnz .invalid
.extent:
    mov rax, r8
    add rax, r9
    jc .overflow
    cmp rdx, r9
    ja .short
    lea rax, [r8 + rdx]
    sub r9, rdx
    mov [rdi], rax
    mov [rsi], r9
    mov [rcx], r8
    xor eax, eax
    ret
.invalid:
    mov eax, -22                ; EINVAL
    ret
.overflow:
    mov eax, -75                ; EOVERFLOW
    ret
.short:
    mov eax, -34                ; ERANGE
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
