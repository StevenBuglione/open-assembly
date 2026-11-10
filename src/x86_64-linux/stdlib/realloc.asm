; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: realloc
; header: stdlib.h
; prototype: void *realloc(void *ptr, size_t size)
; standard: C17 7.22.3.5
; deps: __errno_location, memcpy
; errno: ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: When ptr is NULL, allocate as malloc would. Otherwise ptr must be a live allocation pointer.
; semantics: On success preserve the minimum of the old and new requested sizes and end the old allocation's lifetime.
; semantics: A successful zero-byte resize returns a freeable pointer that exposes no accessible bytes.
; semantics: If allocation fails, the original allocation and contents remain valid even for a zero-byte request.
; semantics: On exhaustion or an unrepresentable allocation size, return NULL and set ENOMEM. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global realloc:function
extern __al_heap:function
extern __errno_location:function

section .text.realloc alloc exec nowrite progbits
realloc:
    push rbp
    mov rbp, rsp
    mov edx, 16
    mov ecx, 2                    ; resize
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
