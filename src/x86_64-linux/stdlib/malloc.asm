; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: malloc
; header: stdlib.h
; prototype: void *malloc(size_t size)
; standard: C17 7.22.3.4
; deps: __errno_location
; errno: ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return new storage for size bytes with at least 16-byte alignment. Contents are indeterminate.
; semantics: A zero-byte request can succeed with a distinct freeable pointer. No byte is accessible through that zero-size allocation.
; semantics: On exhaustion or an unrepresentable allocation size, return NULL and set ENOMEM. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global malloc:function
extern __al_heap:function
extern __errno_location:function

section .text.malloc alloc exec nowrite progbits
malloc:
    push rbp
    mov rbp, rsp
    mov rsi, rdi                  ; size
    xor edi, edi                  ; no old object
    mov edx, 16
    xor ecx, ecx                  ; allocate
    call __al_heap
    test rax, rax
    jnz .done
    call __errno_location
    mov dword [rax], 12           ; ENOMEM
    xor eax, eax
.done:
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
