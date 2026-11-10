; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: glob
; header: glob.h
; prototype: int glob(const char *restrict pattern, int flags, int (*errfunc)(const char *, int), glob_t *restrict result)
; standard: POSIX.1-2024 XSH glob
; deps: __errno_location, calloc, closedir, fnmatch, free, lstat, memcpy, memset, opendir, qsort, readdir, realloc, stat, strcoll, strdup, strlen
; errno: EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: reference:posix-pathname-expansion, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Expand pathname components under the POSIX glob flags and append or sort the resulting batch.
; semantics: Return zero on success or the specified GLOB error code. Preserve matches already stored on failure.
; semantics: Call errfunc for reportable directory open or read errors and stop if it returns nonzero or GLOB_ERR is set.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global glob:function
extern __errno_location:function
extern calloc:function
extern free:function
extern qsort:function
extern __al_glob_parse:function
extern __al_glob_path:function
extern __al_glob_walk:function
extern __al_glob_add:function
extern __al_glob_compare:function

section .text.glob alloc exec nowrite progbits
glob:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov r12, rdi               ; original pattern for GLOB_NOCHECK
    movsxd rsi, esi
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx
    call __errno_location
    mov [rsp], rax
    mov eax, [rax]
    mov [rsp + 8], eax
    test r13d, -128
    jnz .bad_flags
    test r13d, 32              ; GLOB_APPEND
    jnz .context
    mov qword [r15], 0
    mov qword [r15 + 8], 0
    test r13d, 8               ; GLOB_DOOFFS
    jnz .context
    mov qword [r15 + 16], 0
.context:
    mov edi, 1
    mov esi, 256
    call calloc
    test rax, rax
    jz .no_context
    mov rbx, rax
    mov [rbx], r15
    mov [rbx + 8], r13d
    mov [rbx + 16], r14
    mov rax, [rsp]
    mov [rbx + 24], rax
    mov rax, [r15]
    mov [rbx + 48], rax        ; prior count is independent of this batch
    cmp qword [r15 + 8], 0
    je .parse
    add rax, [r15 + 16]
    inc rax                    ; usable capacity of a previous call's vector
    mov [rbx + 40], rax
.parse:
    mov rdi, rbx
    mov rsi, r12
    call __al_glob_parse
    test eax, eax
    jnz .cleanup
    mov rdi, rbx
    xor esi, esi
    mov rdx, [rbx + 104]
    call __al_glob_path
    test eax, eax
    jnz .cleanup
    mov rdi, rbx
    call __al_glob_walk
    test eax, eax
    jnz .cleanup
    mov rsi, [r15]
    sub rsi, [rbx + 48]
    jnz .sort
    test r13d, 16              ; GLOB_NOCHECK
    jz .no_match
    mov rdi, rbx
    mov rsi, r12
    call __al_glob_add
    jmp .cleanup
.sort:
    cmp rsi, 2
    jb .success
    test r13d, 4               ; GLOB_NOSORT
    jnz .success
    mov rax, [r15 + 16]
    add rax, [rbx + 48]
    mov rdi, [r15 + 8]
    lea rdi, [rdi + rax * 8]
    mov edx, 8
    lea rcx, [rel __al_glob_compare]
    call qsort
.success:
    xor eax, eax
    jmp .cleanup
.no_match:
    mov eax, 3                 ; GLOB_NOMATCH
.cleanup:
    mov [rsp + 16], eax
    mov rdi, [rbx + 80]
    call free
    mov rdi, [rbx + 64]
    call free
    mov rdi, [rbx + 56]
    call free
    mov rdi, rbx
    call free
    mov eax, [rsp + 16]
    test eax, eax
    jz .preserve_errno
    cmp eax, 3
    jne .return
.preserve_errno:
    mov rdx, [rsp]
    mov ecx, [rsp + 8]
    mov [rdx], ecx
    jmp .return
.bad_flags:
    mov rdx, [rsp]
    mov dword [rdx], 22        ; EINVAL
    mov eax, 2                 ; GLOB_ABORTED
    jmp .return
.no_context:
    mov eax, 1                 ; GLOB_NOSPACE
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
