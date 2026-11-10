; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fdopendir
; header: dirent.h
; prototype: DIR *fdopendir(int fd)
; standard: POSIX.1-2024 XSH fdopendir
; deps: fstat, malloc, free, __errno_location
; errno: EBADF, EINVAL, ENOMEM, ENOTDIR
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Require a readable directory descriptor. Reject a path-only descriptor.
; semantics: Transfer descriptor ownership on success and set close-on-exec.
; semantics: On failure leave descriptor ownership with the caller.
; semantics: Success preserves errno. Failure returns a null pointer and sets errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fdopendir:function
extern __al_fcntl:function
extern __al_syscall_result:function
extern fstat:function
extern malloc:function
extern free:function

section .text.fdopendir alloc exec nowrite progbits
fdopendir:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    movsxd r12, edi
    mov rdi, r12
    mov esi, 3                    ; F_GETFL
    xor edx, edx
    call __al_fcntl
    cmp rax, -4095
    jae .descriptor_error
    test eax, 0x200000            ; O_PATH
    jnz .bad_fd
    and eax, 3                    ; O_ACCMODE
    test eax, 1                   ; only O_RDONLY and O_RDWR are readable
    jnz .bad_fd
    mov edi, 4408                 ; header, public entry, getdents64 buffer
    call malloc
    test rax, rax
    jz .done
    mov rbx, rax
    mov rdi, r12
    lea rsi, [rbx + 32]           ; entry slot is temporary stat storage
    call fstat
    test eax, eax
    jnz .release
    mov eax, [rbx + 56]           ; stat.st_mode
    and eax, 0xf000               ; S_IFMT
    cmp eax, 0x4000               ; S_IFDIR
    jne .not_directory
    mov rdi, r12
    mov esi, 1                    ; F_GETFD
    xor edx, edx
    call __al_fcntl
    cmp rax, -4095
    jae .close_on_exec_error
    test eax, 1                   ; FD_CLOEXEC
    jnz .initialize
    mov rdx, rax
    or edx, 1                    ; retain existing descriptor flags
    mov rdi, r12
    mov esi, 2                    ; F_SETFD
    call __al_fcntl
    cmp rax, -4095
    jae .close_on_exec_error
.initialize:
    mov dword [rbx], 0           ; lock
    mov [rbx + 4], r12d          ; owned descriptor
    mov qword [rbx + 8], 0       ; buffered offset
    mov qword [rbx + 16], 0      ; buffered byte count
    mov rax, rbx
    jmp .done
.not_directory:
    mov rax, -20                 ; ENOTDIR
.close_on_exec_error:
    mov rdi, rax
    call __al_syscall_result
.release:
    mov rdi, rbx
    call free
    xor eax, eax
    jmp .done
.bad_fd:
    mov rax, -9                  ; EBADF
.descriptor_error:
    mov rdi, rax
    call __al_syscall_result
    xor eax, eax
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
