; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mmap
; header: sys/mman.h
; prototype: void *mmap(void *address, size_t length, int protection, int flags, int fd, off_t offset)
; standard: POSIX.1-2024 XSH mmap
; deps: __errno_location
; errno: EACCES, EAGAIN, EBADF, EEXIST, EINVAL, ENFILE, ENODEV, ENOMEM, EOVERFLOW, EPERM, ETXTBSY
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edx:s32, ecx:s32, r8d:s32
; variadic: false
; semantics: Map anonymous storage or an open file using a byte offset. Return MAP_FAILED and errno on error.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mmap:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.mmap alloc exec nowrite progbits
mmap:
    sub rsp, 8
    mov [rsp], r9
    movsxd r9, r8d
    movsxd r8, ecx
    movsxd rcx, edx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 9                   ; __NR_mmap
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
