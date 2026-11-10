; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsstr
; header: wchar.h
; prototype: wchar_t *wcsstr(const wchar_t *haystack, const wchar_t *needle)
; standard: C17 7.29.4.5.6
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Find the first matching wide substring. An empty needle matches at the start.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsstr:function

section .text.wcsstr alloc exec nowrite progbits
wcsstr:
    cmp dword [rsi], 0
    je .match
.next:
    cmp dword [rdi], 0
    je .miss
    xor ecx, ecx
.compare:
    mov eax, [rsi + rcx*4]
    test eax, eax
    jz .match
    cmp eax, [rdi + rcx*4]
    jne .advance
    inc rcx
    jmp .compare
.advance:
    add rdi, 4
    jmp .next
.match:
    mov rax, rdi
    ret
.miss:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
