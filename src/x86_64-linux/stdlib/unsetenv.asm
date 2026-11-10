; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: unsetenv
; header: stdlib.h
; prototype: int unsetenv(const char *name)
; standard: POSIX.1-2024 XSH unsetenv
; deps: free, __errno_location
; errno: EINVAL
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Remove all entries matching the exact name and keep the array NULL-terminated.
; semantics: Removing an absent name succeeds. Invalid names are NULL, empty or contain equals.
; semantics: Return zero and preserve errno on success. Return -1 with EINVAL on an invalid name.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global unsetenv:function
extern __al_env_change:function

section .text.unsetenv alloc exec nowrite progbits
unsetenv:
    push rbp
    mov rbp, rsp
    xor esi, esi
    mov edx, 1                    ; remove
    xor ecx, ecx
    call __al_env_change
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
