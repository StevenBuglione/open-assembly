; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: putenv
; header: stdlib.h
; prototype: int putenv(char *string)
; standard: POSIX.1-2024 XSH putenv
; deps: malloc, free, __errno_location
; errno: EINVAL, ENOMEM
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Install the actual writable name=value string pointer. Later edits to that string are visible.
; semantics: A nonempty string without equals removes the named variable. Empty names and NULL strings are invalid.
; semantics: Return zero and preserve errno on success. Return -1 and leave the environment unchanged on failure.
; semantics: The caller retains ownership and must keep installed strings alive until removed.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global putenv:function
extern __al_env_change:function

section .text.putenv alloc exec nowrite progbits
putenv:
    push rbp
    mov rbp, rsp
    xor esi, esi
    mov edx, 2                    ; install borrowed string
    mov ecx, 1
    call __al_env_change
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
