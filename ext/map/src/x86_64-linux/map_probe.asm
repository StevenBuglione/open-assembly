; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: map_probe
; header: map.h
; prototype: long map_probe(const size_t *restrict state, const unsigned char *key, size_t length)
; standard: Extension ABI map
; deps: memcmp
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-map-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Find an existing or reusable slot by bounded linear probing with a seeded byte hash.
; semantics: Return twice the slot index plus one for a match, twice the index for a reusable slot, or a negative error.
; semantics: Preserve map and errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global map_probe:function
extern memcmp:function

section .text.map_probe alloc exec nowrite progbits
map_probe:
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jnz .extent
    test rdx, rdx
    jnz .invalid
.extent:
    mov rax, rsi
    add rax, rdx
    jc .overflow
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rax, 0xcbf29ce484222325
    xor rax, [rbx + 24]
    mov r8, 0x100000001b3
    xor ecx, ecx
.hash:
    cmp rcx, r13
    jae .first_slot
    movzx edx, byte [r12 + rcx]
    xor rax, rdx
    imul rax, r8
    inc rcx
    jmp .hash
.first_slot:
    mov rcx, [rbx + 8]
    mov [rsp], rcx             ; inspect at most one full cycle
    dec rcx
    mov [rsp + 8], rcx
    and rax, rcx
    mov r14, rax
    mov r15, -1                ; first removed slot, if any
.slot:
    mov rax, r14
    shl rax, 5
    add rax, [rbx]
    cmp qword [rax], 0
    je .vacant
    cmp qword [rax], 1
    je .removed
    cmp r13, [rax + 16]
    jne .advance
    test r13, r13
    jz .found
    mov rdi, r12
    mov rsi, [rax + 8]
    mov rdx, r13
    call memcmp
    test eax, eax
    jz .found
    jmp .advance
.removed:
    cmp r15, -1
    jne .advance
    mov r15, r14
.advance:
    dec qword [rsp]
    jz .cycle_end
    inc r14
    and r14, [rsp + 8]
    jmp .slot
.found:
    lea rax, [r14 * 2 + 1]
    jmp .return
.vacant:
    cmp r15, -1
    jne .reuse
    lea rax, [r14 * 2]
    jmp .return
.cycle_end:
    cmp r15, -1
    jne .reuse
    mov rax, -28               ; ENOSPC
    jmp .return
.reuse:
    lea rax, [r15 * 2]
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov rax, -22               ; EINVAL
    ret
.overflow:
    mov rax, -75               ; EOVERFLOW
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
