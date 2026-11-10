; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: slice_load_u32be
; header: slice.h
; prototype: int slice_load_u32be(const unsigned char *bytes, size_t length, unsigned int *restrict result)
; standard: Extension ABI slice
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-slice-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read exactly four bytes at the start of the slice as a big-endian unsigned integer.
; semantics: Return -EINVAL for invalid arguments, -EOVERFLOW for a wrapping span, or -ERANGE for fewer than four bytes.
; semantics: Preserve result on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global slice_load_u32be:function

section .text.slice_load_u32be alloc exec nowrite progbits
slice_load_u32be:
    test rdx, rdx
    jz .invalid
    test rdi, rdi
    jnz .extent
    test rsi, rsi
    jnz .invalid
.extent:
    mov rax, rdi
    add rax, rsi
    jc .overflow
    cmp rsi, 4
    jb .short
    mov eax, [rdi]
    bswap eax
    mov [rdx], eax
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
