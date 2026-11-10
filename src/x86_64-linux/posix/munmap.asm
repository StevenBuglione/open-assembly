; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: munmap
; header: sys/mman.h
; prototype: int munmap(void *address, size_t length)
; standard: POSIX.1-2024 XSH munmap
; deps: __errno_location
; errno: EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Unmap the specified range using the native Linux mapping boundaries.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global munmap:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.munmap alloc exec nowrite progbits
munmap:
    sub rsp, 8
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 11                  ; __NR_munmap
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
