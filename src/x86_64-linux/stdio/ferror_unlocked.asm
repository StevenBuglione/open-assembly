; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ferror_unlocked
; header: stdio.h
; prototype: int ferror_unlocked(FILE *stream)
; standard: Extension ABI ferror_unlocked
; deps: -
; errno: -
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read the stream error indicator and return zero or a nonzero value.
; semantics: Do not acquire the stdio lock. The caller is responsible for synchronization.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ferror_unlocked:function

section .text.ferror_unlocked alloc exec nowrite progbits
ferror_unlocked:
    mov eax, [rdi + 8]
    and eax, 32                   ; stream error flag
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
