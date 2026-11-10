; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: arena_alloc
; header: arena.h
; prototype: int arena_alloc(size_t *restrict state, size_t size, size_t alignment, void **restrict result)
; standard: Extension ABI arena
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-state-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return an aligned pointer from caller-owned storage and advance used for nonzero size.
; semantics: Require positive power-of-two alignment. A zero-size request leaves used unchanged.
; semantics: Report -EINVAL for invalid arguments, -EOVERFLOW for wrapping arithmetic, or -ENOSPC for insufficient capacity.
; semantics: Preserve state and result on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global arena_alloc:function

section .text.arena_alloc alloc exec nowrite progbits
arena_alloc:
    test rdi, rdi
    jz .invalid
    test rcx, rcx
    jz .invalid
    test rdx, rdx
    jz .invalid
    lea r8, [rdx - 1]
    test rdx, r8
    jnz .invalid
    mov r9, [rdi]              ; base address
    mov r10, [rdi + 8]         ; capacity
    mov r11, [rdi + 16]        ; used
    cmp r11, r10
    ja .invalid
    test r9, r9
    jnz .extent
    test r10, r10
    jnz .invalid
.extent:
    mov rax, r9
    add rax, r10
    jc .overflow
    lea rax, [r9 + r11]        ; extent check also bounds base plus used
    add rax, r8
    jc .overflow
    not r8
    and rax, r8                ; aligned allocation address
    mov rdx, rax
    sub rdx, r9
    add rdx, rsi               ; new used count
    jc .overflow
    cmp rdx, r10
    ja .full
    test rsi, rsi
    jz .publish
    mov [rdi + 16], rdx
.publish:
    mov [rcx], rax
    xor eax, eax
    ret
.invalid:
    mov eax, -22               ; EINVAL
    ret
.overflow:
    mov eax, -75               ; EOVERFLOW
    ret
.full:
    mov eax, -28               ; ENOSPC
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
