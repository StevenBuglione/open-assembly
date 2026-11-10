; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: slice_find_byte
; header: slice.h
; prototype: int slice_find_byte(const unsigned char *bytes, size_t length, unsigned int needle, size_t *restrict offset)
; standard: Extension ABI slice
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-slice-model
; provenance: original
; narrow_args: edx:u32
; variadic: false
; semantics: Store the first offset of the requested byte in the bounded slice.
; semantics: Return -EINVAL for invalid arguments or a needle above 255, -EOVERFLOW for a wrapping span, or -ENOENT if the byte is absent.
; semantics: Preserve offset on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global slice_find_byte:function

section .text.slice_find_byte alloc exec nowrite progbits
slice_find_byte:
    mov edx, edx
    cmp edx, 255
    ja .invalid
    test rcx, rcx
    jz .invalid
    test rdi, rdi
    jnz .extent
    test rsi, rsi
    jnz .invalid
.extent:
    mov rax, rdi
    add rax, rsi
    jc .overflow
    xor eax, eax
.next:
    cmp rax, rsi
    jae .absent
    cmp [rdi + rax], dl
    je .found
    inc rax
    jmp .next
.found:
    mov [rcx], rax
    xor eax, eax
    ret
.invalid:
    mov eax, -22                ; EINVAL
    ret
.overflow:
    mov eax, -75                ; EOVERFLOW
    ret
.absent:
    mov eax, -2                 ; ENOENT
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
