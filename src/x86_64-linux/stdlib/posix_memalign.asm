; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_memalign
; header: stdlib.h
; prototype: int posix_memalign(void **out, size_t alignment, size_t size)
; standard: POSIX.1-2024 XSH posix_memalign
; deps: -
; errno: EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Require alignment to be a power of two and a multiple of sizeof(void *).
; semantics: On success store a freeable aligned allocation in out and return zero.
; semantics: On invalid alignment return EINVAL. On allocation failure return ENOMEM. Leave out unchanged on failure.
; semantics: Preserve errno. A zero-size request follows the allocator's freeable-pointer policy.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_memalign:function
extern __al_heap:function

section .text.posix_memalign alloc exec nowrite progbits
posix_memalign:
    cmp rsi, 8
    jb .invalid
    lea rax, [rsi - 1]
    test rsi, rax
    jnz .invalid

    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rsp], rdi                ; result storage, written only on success
    mov r8, rsi                   ; requested alignment
    cmp r8, 16
    jae .allocate
    mov r8d, 16
.allocate:
    xor edi, edi
    mov rsi, rdx
    mov rdx, r8
    xor ecx, ecx
    call __al_heap
    test rax, rax
    jz .no_memory
    mov rdi, [rsp]
    mov [rdi], rax
    xor eax, eax
    jmp .done
.no_memory:
    mov eax, 12                   ; ENOMEM
.done:
    add rsp, 16
    pop rbp
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
