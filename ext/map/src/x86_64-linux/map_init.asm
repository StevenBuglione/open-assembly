; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: map_init
; header: map.h
; prototype: int map_init(size_t *restrict state, size_t *restrict slots, size_t capacity, size_t seed)
; standard: Extension ABI map
; deps: memset
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-map-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize a fixed-capacity table of four-word slots and a caller-owned four-word state.
; semantics: Require a positive power-of-two capacity and a representable slot extent. Preserve state, slots and errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global map_init:function
extern memset:function

section .text.map_init alloc exec nowrite progbits
map_init:
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jz .invalid
    test rdx, rdx
    jz .invalid
    lea rax, [rdx - 1]
    test rax, rdx
    jnz .invalid
    mov rax, rdx
    shr rax, 59
    jnz .overflow
    mov rax, rdx
    shl rax, 5                 ; four words per slot
    mov r8, rsi
    add r8, rax
    jc .overflow
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov rdi, rsi
    xor esi, esi
    mov rdx, rax
    call memset
    mov [rbx], r12
    mov [rbx + 8], r13
    mov qword [rbx + 16], 0
    mov [rbx + 24], r14
    xor eax, eax
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, -22                ; EINVAL
    ret
.overflow:
    mov eax, -75                ; EOVERFLOW
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
