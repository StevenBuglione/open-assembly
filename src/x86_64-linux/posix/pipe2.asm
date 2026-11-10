; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pipe2
; header: unistd.h
; prototype: int pipe2(int fildes[2], int flags)
; standard: POSIX.1-2024 XSH pipe2
; deps: __errno_location
; errno: EFAULT, EINVAL, EMFILE, ENFILE, ENOMEM
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Create a pipe with flags applied atomically to both descriptors.
; semantics: Support Linux close-on-exec and nonblocking flags. The kernel validates other command bits.
; semantics: Store the read descriptor first and the write descriptor second.
; semantics: Return zero and preserve errno on success. Leave the output array unchanged and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pipe2:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.pipe2 alloc exec nowrite progbits
pipe2:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rdx, esi
    mov rsi, rdi
    mov edi, 293                 ; __NR_pipe2
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
