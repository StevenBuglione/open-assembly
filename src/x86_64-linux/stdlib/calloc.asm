; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: calloc
; header: stdlib.h
; prototype: void *calloc(size_t nmemb, size_t size)
; standard: C17 7.22.3.2
; deps: __errno_location, memset
; errno: ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return new storage for nmemb objects of size bytes each and initialize every requested byte to zero.
; semantics: Check the product before allocating. If either factor is zero, treat it as a zero-byte request.
; semantics: A zero-byte request can succeed with a distinct freeable pointer. No byte is accessible through that zero-size allocation.
; semantics: On exhaustion or an unrepresentable allocation size, return NULL and set ENOMEM. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global calloc:function
extern __al_heap:function
extern __errno_location:function

section .text.calloc alloc exec nowrite progbits
calloc:
    push rbp
    mov rbp, rsp
    test rdi, rdi
    jz .allocate
    test rsi, rsi
    jz .zero
    mov rax, 0x7fffffffffffffff   ; PTRDIFF_MAX
    xor edx, edx
    div rsi
    cmp rdi, rax
    ja .no_memory
    imul rdi, rsi
    jmp .allocate
.zero:
    xor edi, edi
.allocate:
    mov rsi, rdi
    xor edi, edi
    mov edx, 16
    mov ecx, 3                    ; allocate and zero
    call __al_heap
    test rax, rax
    jnz .done
.no_memory:
    call __errno_location
    mov dword [rax], 12           ; ENOMEM
    xor eax, eax
.done:
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
