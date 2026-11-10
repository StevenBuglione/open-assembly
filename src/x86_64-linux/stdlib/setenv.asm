; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: setenv
; header: stdlib.h
; prototype: int setenv(const char *name, const char *value, int overwrite)
; standard: POSIX.1-2024 XSH setenv
; deps: malloc, free, memcpy, strlen, __errno_location
; errno: EINVAL, ENOMEM
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Copy name and value into the environment. If overwrite is zero, keep an existing value unchanged.
; semantics: Accept empty values and equals signs in values. Reject NULL or empty names and names containing equals with EINVAL.
; semantics: A NULL value is invalid and is rejected with EINVAL.
; semantics: Return zero and preserve errno on success. On failure return -1 and leave the environment unchanged.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global setenv:function
extern __al_env_change:function

section .text.setenv alloc exec nowrite progbits
setenv:
    push rbp
    mov rbp, rsp
    movsxd rcx, edx               ; overwrite
    xor edx, edx                  ; set
    call __al_env_change
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
