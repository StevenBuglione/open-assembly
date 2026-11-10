; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: map_put
; header: map.h
; prototype: int map_put(size_t *restrict state, size_t *restrict arena_state, const unsigned char *key, size_t length, size_t value)
; standard: Extension ABI map
; deps: arena_alloc, map_probe, memmove
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-map-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Update an existing value or insert an owned key copied into the caller-owned arena.
; semantics: Preserve the map and arena on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global map_put:function
extern map_probe:function
extern arena_alloc:function
extern memmove:function

section .text.map_put alloc exec nowrite progbits
map_put:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov rsi, r13
    mov rdx, r14
    call map_probe
    test rax, rax
    js .return
    mov rdx, rax
    shr rax, 1
    shl rax, 5
    add rax, [rbx]
    test dl, 1
    jnz .value
    test r14, r14
    jz .empty_key
    mov [rsp], rax
    mov rdi, r12
    mov rsi, r14
    mov edx, 1
    lea rcx, [rax + 8]
    call arena_alloc
    test eax, eax
    jnz .return
    mov rax, [rsp]
    mov rdi, [rax + 8]
    mov rsi, r13
    mov rdx, r14
    call memmove
    mov rax, [rsp]
    jmp .insert
.empty_key:
    mov qword [rax + 8], 0
.insert:
    mov [rax + 16], r14
    mov [rax + 24], r15
    mov qword [rax], 2         ; publish the new key after its bytes
    inc qword [rbx + 16]
    jmp .success
.value:
    mov [rax + 24], r15
.success:
    xor eax, eax
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
