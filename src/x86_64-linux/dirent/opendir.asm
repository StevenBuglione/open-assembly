; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: opendir
; header: dirent.h
; prototype: DIR *opendir(const char *name)
; standard: POSIX.1-2024 XSH opendir
; deps: open, fdopendir, close, __errno_location
; errno: EACCES, EBADF, ELOOP, EMFILE, ENAMETOOLONG, ENFILE, ENOENT, ENOMEM, ENOTDIR
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Open a readable directory with close-on-exec and return an owned stream.
; semantics: If stream creation fails, close the temporary descriptor and retain the cause in errno.
; semantics: Success preserves errno. Failure returns a null pointer and sets errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global opendir:function
extern open:function
extern fdopendir:function
extern close:function
extern __errno_location:function

section .text.opendir alloc exec nowrite progbits
opendir:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov esi, 0x90000             ; O_DIRECTORY | O_CLOEXEC | O_RDONLY
    xor eax, eax                  ; no variadic vector arguments
    call open
    test eax, eax
    js .failed
    movsxd rbx, eax
    mov rdi, rbx
    call fdopendir
    test rax, rax
    jnz .done
    call __errno_location
    mov r12d, [rax]
    mov rdi, rbx
    call close
    call __errno_location
    mov [rax], r12d               ; retain the stream creation error
.failed:
    xor eax, eax
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
