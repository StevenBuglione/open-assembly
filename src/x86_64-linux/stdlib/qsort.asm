; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: qsort
; header: stdlib.h
; prototype: void qsort(void *base, size_t nmemb, size_t size, int (*compar)(const void *, const void *))
; standard: C17 7.22.5.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, reference:sorted-permutation
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Sort the array in place in ascending comparator order. Equal elements need not retain their original order.
; semantics: Pass only pointers to actual in-array elements to compar and use only the sign of its int result.
; semantics: With fewer than two elements or zero element size, return without calling compar or writing the array.
; semantics: A comparator that gives inconsistent answers may produce an unspecified permutation. The sort remains bounded and never accesses beyond a valid array.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global qsort:function

section .text.qsort alloc exec nowrite progbits
qsort:
    cmp rsi, 2
    jb .empty
    test rdx, rdx
    jz .empty
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov rbx, rdi                  ; array base
    mov r12, rdx                  ; element width
    mov r13, rsi                  ; count still in the heap
    mov r15, rcx                  ; comparator
    mov rax, rsi
    shr rax, 1
    mov [rsp], rax                ; first leaf, then next parent plus one

.next_parent:
    mov rax, [rsp]
    test rax, rax
    jz .extract
    dec rax
    mov [rsp], rax
    mov r14, rax
    jmp .sift

.extract:
    ; Move the heap maximum to the end, then re-heapify the remainder.
    dec r13
    jz .done
    mov rdi, rbx
    mov rsi, r13
    imul rsi, r12
    add rsi, rbx
    mov rcx, r12
.swap_maximum:
    mov al, [rdi]
    mov dl, [rsi]
    mov [rdi], dl
    mov [rsi], al
    inc rdi
    inc rsi
    dec rcx
    jnz .swap_maximum
    xor r14d, r14d                ; restart from the heap root

.sift:
    ; A node has children only when its index is below floor(count / 2).
    mov rax, r13
    shr rax, 1
    cmp r14, rax
    jae .next_parent
    lea rax, [r14*2 + 1]
    mov [rsp + 8], rax            ; left child, then larger child
    inc rax
    cmp rax, r13
    jae .compare_parent

    mov rdi, [rsp + 8]
    imul rdi, r12
    add rdi, rbx
    mov rsi, rax
    imul rsi, r12
    add rsi, rbx
    mov rax, r15
    call rax
    test eax, eax
    jge .compare_parent
    inc qword [rsp + 8]           ; right child compares greater

.compare_parent:
    mov rdi, r14
    imul rdi, r12
    add rdi, rbx
    mov rsi, [rsp + 8]
    imul rsi, r12
    add rsi, rbx
    mov [rsp + 16], rsi
    mov rax, r15
    call rax
    test eax, eax
    jge .next_parent

    mov rdi, r14                  ; comparator may clobber caller registers
    imul rdi, r12
    add rdi, rbx
    mov rsi, [rsp + 16]
    mov rcx, r12
.swap_parent:
    mov al, [rdi]
    mov dl, [rsi]
    mov [rdi], dl
    mov [rsi], al
    inc rdi
    inc rsi
    dec rcx
    jnz .swap_parent
    mov r14, [rsp + 8]            ; descend one level after each swap
    jmp .sift

.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
.empty:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
