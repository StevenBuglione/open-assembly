; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: bsearch
; header: stdlib.h
; prototype: void *bsearch(const void *key, const void *base, size_t nmemb, size_t size, int (*compar)(const void *, const void *))
; standard: C17 7.22.5.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, reference:sorted-search
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Search an array partitioned into less than, equal to, and greater than the key in that order.
; semantics: Pass the key first and an in-array element pointer second to compar. Use only the sign of its int result.
; semantics: Return any matching element or NULL if none matches. Zero elements or zero element size return NULL without calling compar.
; semantics: The implementation never probes beyond a valid array, even when compar reports inconsistent orderings.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global bsearch:function

section .text.bsearch alloc exec nowrite progbits
bsearch:
    test rdx, rdx
    jz .empty
    test rcx, rcx
    jz .empty
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov rbx, rsi                  ; array base
    mov r12, rcx                  ; element width
    mov r13, rdi                  ; key
    mov r14, rdx                  ; exclusive upper index
    mov r15, r8                   ; comparator
    mov qword [rsp], 0            ; inclusive lower index

.next:
    mov rax, [rsp]
    cmp rax, r14
    jae .missing
    mov rdx, r14
    sub rdx, rax
    shr rdx, 1
    add rax, rdx                  ; midpoint without overflowing
    mov [rsp + 8], rax
    imul rax, r12
    add rax, rbx
    mov [rsp + 16], rax           ; candidate address
    mov rdi, r13
    mov rsi, rax
    mov rax, r15
    call rax
    test eax, eax
    jz .found
    jg .raise_lower
    mov r14, [rsp + 8]
    jmp .next
.raise_lower:
    mov rax, [rsp + 8]
    inc rax
    mov [rsp], rax
    jmp .next
.found:
    mov rax, [rsp + 16]
    jmp .done
.missing:
    xor eax, eax
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.empty:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
