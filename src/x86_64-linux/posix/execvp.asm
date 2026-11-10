; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: execvp
; header: unistd.h
; prototype: int execvp(const char *file, char *const argv[])
; standard: POSIX.1-2024 XSH execvp
; deps: getenv, malloc, free, __errno_location
; errno: E2BIG, EACCES, EFAULT, EINVAL, EIO, EISDIR, ELIBBAD, ELOOP, EMFILE, ENAMETOOLONG, ENFILE, ENOENT, ENOEXEC, ENOMEM, ENOTDIR, EPERM, ETXTBSY
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-exec-path
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Use current environ and search its PATH from left to right when file contains no slash.
; semantics: An empty PATH element means the current directory. Use /bin:/usr/bin when PATH is unset.
; semantics: Continue past missing paths and non-directories. Remember permission denial across the search.
; semantics: On ENOEXEC invoke /bin/sh with the candidate path and the arguments after argv[0].
; semantics: A successful replacement does not return. A returned error is -1 and sets errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global execvp:function
extern environ:data
extern malloc:function
extern free:function
extern __al_exec_path_env:function
extern __al_exec_search:function
extern __al_syscall_result:function

section .text.execvp alloc exec nowrite progbits
execvp:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov edi, 4096
    call malloc
    test rax, rax
    jz .no_memory
    mov r13, rax
    call __al_exec_path_env
    mov rdi, rbx
    mov rsi, r12
    mov rdx, [rel environ]
    mov rcx, rax
    mov r8, r13
    mov r9d, 1                    ; execvp interprets ENOEXEC via the shell
    call __al_exec_search
    mov r14, rax
    mov rdi, r13
    call free
    mov rdi, r14
    jmp .result
.no_memory:
    mov rdi, -12
.result:
    call __al_syscall_result
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
