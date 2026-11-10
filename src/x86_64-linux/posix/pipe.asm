; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pipe
; header: unistd.h
; prototype: int pipe(int fildes[2])
; standard: POSIX.1-2024 XSH pipe
; deps: __errno_location
; errno: EFAULT, EMFILE, ENFILE, ENOMEM
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Create a blocking pipe and store the read descriptor first and the write descriptor second.
; semantics: Both descriptors start with close-on-exec clear.
; semantics: Return zero on success and leave the array unchanged on kernel failure.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pipe:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.pipe alloc exec nowrite progbits
pipe:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rsi, rdi                   ; output descriptor pair
    mov edi, 22                    ; __NR_pipe
    xor edx, edx
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
