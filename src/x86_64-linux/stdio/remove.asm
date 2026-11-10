; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: remove
; header: stdio.h
; prototype: int remove(const char *path)
; standard: C17 7.21.4.1
; deps: __errno_location
; errno: EACCES, EBUSY, EFAULT, ELOOP, ENAMETOOLONG, ENOENT, ENOTDIR, ENOTEMPTY, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-temporary-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Remove a file or symbolic-link name, or remove a directory when empty.
; semantics: Preserve open file descriptions after removing their last name.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global remove:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.remove alloc exec nowrite progbits
remove:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov qword [rsp], 0
    mov rbx, rdi
    mov rsi, rdi
    mov edi, 87                   ; __NR_unlink
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -21                  ; EISDIR
    jne .result
    mov edi, 84                   ; __NR_rmdir
    mov rsi, rbx
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
.result:
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
