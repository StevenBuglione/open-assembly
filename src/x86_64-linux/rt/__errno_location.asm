; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __errno_location
; header: errno.h
; prototype: int *__errno_location(void)
; standard: Runtime ABI __errno_location, C17 7.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:runtime-abi, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return a stable, writable pointer to the calling thread's errno integer.
; semantics: The initial thread's errno starts at zero; obtaining the pointer does not change it.
; semantics: The runtime ABI locates errno at offset 0x40 from the current thread pointer after startup.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __errno_location:function

section .text.__errno_location alloc exec nowrite progbits
__errno_location:
    mov rax, [fs:0]
    add rax, 0x40
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
