; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: closedir
; header: dirent.h
; prototype: int closedir(DIR *dirp)
; standard: POSIX.1-2024 XSH closedir
; deps: close, free
; errno: EBADF, EINTR, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Close the owned descriptor and release the stream storage.
; semantics: Return zero on success and preserve errno. Return -1 and set errno on error.
; semantics: The stream is invalid after the call.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global closedir:function
extern close:function
extern free:function

section .text.closedir alloc exec nowrite progbits
closedir:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    movsxd rdi, dword [rbx + 4]
    call close
    mov r12d, eax
    mov rdi, rbx
    call free
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
