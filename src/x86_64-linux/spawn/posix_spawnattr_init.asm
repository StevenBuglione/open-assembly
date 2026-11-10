; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnattr_init
; header: spawn.h
; prototype: int posix_spawnattr_init(posix_spawnattr_t *attr)
; standard: POSIX.1-2024 XSH posix_spawnattr_init
; deps: calloc, __errno_location
; errno: ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize a reusable attribute object with zero flags, process group, and masks.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnattr_init:function
extern __errno_location:function
extern calloc:function

section .text.posix_spawnattr_init alloc exec nowrite progbits
posix_spawnattr_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rdi
    call __errno_location
    mov r12, rax
    mov r13d, [rax]
    mov edi, 1
    mov esi, 32
    call calloc
    mov [r12], r13d
    test rax, rax
    jz .no_memory
    mov [rbx], rax
    mov qword [rbx + 8], 0
    xor eax, eax
    jmp .done
.no_memory:
    mov eax, 12                   ; ENOMEM
.done:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
