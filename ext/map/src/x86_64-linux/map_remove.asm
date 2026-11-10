; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: map_remove
; header: map.h
; prototype: int map_remove(size_t *restrict state, const unsigned char *key, size_t length, size_t *restrict value)
; standard: Extension ABI map
; deps: map_probe
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-map-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Remove an existing key and optionally return its value. A missing key returns -ENOENT.
; semantics: Preserve outputs on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global map_remove:function
extern map_probe:function

section .text.map_remove alloc exec nowrite progbits
map_remove:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rcx
    call map_probe
    test rax, rax
    js .lookup_error
    test al, 1
    jz .absent
    shr rax, 1
    shl rax, 5
    add rax, [rbx]
    test r12, r12
    jz .remove
    mov rdx, [rax + 24]
    mov [r12], rdx
.remove:
    mov qword [rax], 1          ; retain the probe chain through this slot
    mov qword [rax + 8], 0
    mov qword [rax + 16], 0
    mov qword [rax + 24], 0
    dec qword [rbx + 16]
    xor eax, eax
    jmp .return
.lookup_error:
    cmp eax, -28
    jne .return
.absent:
    mov eax, -2                ; ENOENT
.return:
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
