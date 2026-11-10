; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tmpfile
; header: stdio.h
; prototype: FILE *tmpfile(void)
; standard: C17 7.21.4.3
; deps: malloc, free, memcpy, strlen, close, unlink, __errno_location
; errno: EACCES, EEXIST, EIO, EMFILE, ENOENT, ENOMEM, ENOSPC, EROFS
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-temporary-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return a new fully buffered binary update stream backed by an anonymous file in /tmp.
; semantics: Prefer an anonymous Linux temporary inode and fall back to an exclusive file immediately unlinked.
; semantics: Use close-on-exec descriptors. Release temporary memory and descriptors on any setup error.
; semantics: Return null and set errno on failure. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tmpfile:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __al_mktemp:function
extern __errno_location:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_init:function
extern malloc:function
extern free:function
extern memcpy:function
extern close:function
extern unlink:function

section .text.tmpfile alloc exec nowrite progbits
tmpfile:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov qword [rsp], 0
    mov edi, 257                  ; __NR_openat
    mov rsi, -100                 ; AT_FDCWD
    lea rdx, [rel temporary_directory]
    mov ecx, 0x490082            ; O_TMPFILE | O_CLOEXEC | O_EXCL | O_RDWR
    mov r8d, 384                  ; 0600
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jb .anonymous
    cmp rax, -95                  ; EOPNOTSUPP
    je .named
    cmp rax, -22                  ; EINVAL
    je .named
    cmp rax, -21                  ; EISDIR on older kernels
    je .named
    cmp rax, -38                  ; ENOSYS
    je .named
    mov rdi, rax
    call __al_syscall_result
    jmp .failure
.named:
    mov edi, 26                   ; template including NUL
    call malloc
    test rax, rax
    jz .failure
    mov rbx, rax
    mov rdi, rax
    lea rsi, [rel temporary_template]
    mov edx, 26
    call memcpy
    mov rdi, rbx
    mov esi, 0x80000             ; O_CLOEXEC
    call __al_mktemp
    mov r12, rax
    test rax, rax
    js .release_template
    mov rdi, rbx
    call unlink
    mov r13d, eax
    mov rdi, rbx
    call free
    test r13d, r13d
    jnz .release_descriptor
    jmp .open_stream
.release_template:
    mov rdi, rbx
    call free
    jmp .failure
.anonymous:
    mov r12, rax
.open_stream:
    mov edi, 4272                 ; FILE and its inline buffer
    call malloc
    test rax, rax
    jz .release_descriptor
    mov r13, rax
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    mov rdi, r13
    mov rsi, r12
    mov edx, 11                   ; heap-owned, readable and writable
    call __al_stream_init
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov rax, r13
    jmp .done
.release_descriptor:
    call __errno_location
    mov r13d, [rax]
    mov rdi, r12
    call close
    call __errno_location
    mov [rax], r13d
.failure:
    xor eax, eax
.done:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.tmpfile alloc noexec nowrite progbits
temporary_directory:
    db '/tmp', 0
temporary_template:
    db '/tmp/open-assembly.XXXXXX', 0

section .note.GNU-stack noalloc noexec nowrite progbits
