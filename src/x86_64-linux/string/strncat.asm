; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strncat
; header: string.h
; prototype: char *strncat(char *restrict dest, const char *restrict src, size_t n)
; standard: C17 7.24.3.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Append at most n nonzero source bytes to the original destination terminator and terminate dest.
; semantics: Return dest. For n equal to zero, leave dest unchanged and do not read src.
; semantics: The regions must not overlap and dest must have space for the result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strncat:function

section .text.strncat alloc exec nowrite progbits
strncat:
    mov rax, rdi
    test rdx, rdx
    jz .done
.find_end:
    cmp byte [rdi], 0
    je .append
    inc rdi
    jmp .find_end
.append:
    mov cl, [rsi]
    test cl, cl
    jz .terminate
    mov [rdi], cl
    inc rdi
    inc rsi
    dec rdx
    jnz .append
.terminate:
    mov byte [rdi], 0
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
