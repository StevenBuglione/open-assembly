; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: lseek
; header: unistd.h
; prototype: off_t lseek(int fd, off_t offset, int whence)
; standard: POSIX.1-2024 XSH lseek
; deps: __errno_location
; errno: EBADF, EINVAL, ENXIO, EOVERFLOW, ESPIPE
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: edi:s32, edx:s32
; variadic: false
; semantics: Pass the full signed 64-bit offset to the Linux kernel.
; semantics: Return the full resulting offset and update the shared open file description.
; semantics: The filesystem determines support and results for Linux data and hole seeks.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global lseek:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.lseek alloc exec nowrite progbits
lseek:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rcx, edx                ; whence
    mov rdx, rsi                   ; offset remains signed 64-bit
    movsxd rsi, edi                ; descriptor
    mov edi, 8                     ; __NR_lseek
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
