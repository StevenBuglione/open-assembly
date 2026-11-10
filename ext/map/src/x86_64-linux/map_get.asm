; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: map_get
; header: map.h
; prototype: int map_get(const size_t *restrict state, const unsigned char *key, size_t length, size_t *restrict value)
; standard: Extension ABI map
; deps: map_probe
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:bounded-map-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Publish the value for an existing length-delimited key or return -ENOENT.
; semantics: Preserve the output on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global map_get:function
extern map_probe:function

section .text.map_get alloc exec nowrite progbits
map_get:
    test rcx, rcx
    jz .invalid
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
    mov rdx, [rax + 24]
    mov [r12], rdx
    xor eax, eax
    jmp .return
.lookup_error:
    cmp eax, -28               ; a full table can also lack this key
    jne .return
.absent:
    mov eax, -2                ; ENOENT
.return:
    add rsp, 8
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, -22               ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
