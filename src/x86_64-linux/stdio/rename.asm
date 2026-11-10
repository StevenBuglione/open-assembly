; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: rename
; header: stdio.h
; prototype: int rename(const char *oldpath, const char *newpath)
; standard: C17 7.21.4.2
; deps: __errno_location
; errno: EACCES, EBUSY, EFAULT, EINVAL, EISDIR, ELOOP, ENAMETOOLONG, ENOENT, ENOTDIR, ENOTEMPTY, EPERM, EROFS, EXDEV
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-temporary-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Rename the path with the usual Linux replacement and symbolic-link behavior.
; semantics: Let the kernel perform the atomic name change and permission checks.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global rename:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.rename alloc exec nowrite progbits
rename:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 82                   ; __NR_rename
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
