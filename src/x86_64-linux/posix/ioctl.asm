; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ioctl
; header: sys/ioctl.h
; prototype: int ioctl(int fd, unsigned long request, ...)
; standard: Extension ABI ioctl
; deps: __errno_location
; errno: EBADF, EFAULT, EINVAL, ENOTTY
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: edi:s32
; variadic: true
; semantics: Pass the descriptor, Linux command, and machine-word payload to the kernel ioctl operation.
; semantics: Linux commands with no payload ignore the third machine word.
; semantics: Return the kernel result and preserve errno on success. Translate a kernel failure to -1 and errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ioctl:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.ioctl alloc exec nowrite progbits
ioctl:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rcx, rdx                   ; optional machine-word payload
    mov edx, esi                   ; Linux uses a 32-bit request
    movsxd rsi, edi
    mov edi, 16                    ; __NR_ioctl
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
