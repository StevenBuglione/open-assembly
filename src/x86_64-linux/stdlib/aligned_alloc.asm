; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: aligned_alloc
; header: stdlib.h
; prototype: void *aligned_alloc(size_t alignment, size_t size)
; standard: C17 7.22.3.1
; deps: __errno_location
; errno: EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Require nonzero power-of-two alignment. Return NULL with EINVAL for other alignments.
; semantics: Return storage aligned to at least 16 and to alignment, with exactly size requested bytes.
; semantics: Sizes need not be multiples of alignment. The return value can be released with free.
; semantics: A zero-byte request can succeed with a distinct freeable pointer. No byte is accessible through that zero-size allocation.
; semantics: On exhaustion or an unrepresentable allocation size, return NULL and set ENOMEM. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global aligned_alloc:function
extern __al_heap:function
extern __errno_location:function

section .text.aligned_alloc alloc exec nowrite progbits
aligned_alloc:
    push rbp
    mov rbp, rsp
    test rdi, rdi
    jz .invalid
    lea rdx, [rdi - 1]
    test rdi, rdx
    jnz .invalid
    mov rdx, rdi
    cmp rdx, 16
    jae .allocate
    mov edx, 16
.allocate:
    xor edi, edi
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
.invalid:
    call __errno_location
    mov dword [rax], 22           ; EINVAL
    xor eax, eax
    jmp .done

section .note.GNU-stack noalloc noexec nowrite progbits
