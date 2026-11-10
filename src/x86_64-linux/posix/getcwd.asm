; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getcwd
; header: unistd.h
; prototype: char *getcwd(char *buf, size_t size)
; standard: POSIX.1-2024 XSH getcwd
; deps: malloc, free, __errno_location
; errno: EACCES, EFAULT, EINVAL, ENAMETOOLONG, ENOENT, ENOMEM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Write the absolute working-directory pathname and its terminating NUL into caller storage.
; semantics: A nonnull buf needs positive size. Return buf on success, or null and errno on failure.
; semantics: For the Linux allocator extension, allocate size bytes when buf is null and size is positive.
; semantics: When both buf and size are zero, allocate enough storage for the direct Linux getcwd limit.
; semantics: The caller owns allocated results. Preserve errno on success and discard temporary storage on error.
; semantics: Report the direct Linux getcwd pathname limit and reject unreachable working directories.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getcwd:function
extern __al_syscall:function
extern __al_syscall_result:function
extern malloc:function
extern free:function

section .text.getcwd alloc exec nowrite progbits
getcwd:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 24
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
    test rbx, rbx
    jz .allocate
    test r12, r12
    jnz .read_path
    mov rax, -22                  ; EINVAL
    jmp .error
.allocate:
    test r12, r12
    jnz .allocate_size
    mov r12d, 4096                ; Linux direct getcwd limit
.allocate_size:
    mov rdi, r12
    call malloc
    test rax, rax
    jz .done
    mov rbx, rax
    mov r13d, 1
.read_path:
    mov qword [rsp], 0
    mov edi, 79                    ; __NR_getcwd
    mov rsi, rbx
    mov rdx, r12
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .error
    cmp byte [rbx], 47            ; reachable paths start with slash
    jne .unreachable
    mov rax, rbx
    jmp .done
.unreachable:
    mov rax, -2                   ; ENOENT
.error:
    mov rdi, rax
    call __al_syscall_result
    test r13d, r13d
    jz .null
    mov rdi, rbx
    call free
.null:
    xor eax, eax
.done:
    add rsp, 24
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
