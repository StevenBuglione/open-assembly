; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tmpnam
; header: stdio.h
; prototype: char *tmpnam(char *buffer)
; standard: C17 7.21.4.4
; deps: __errno_location, getpid, lstat, memcpy, stat
; errno: EACCES, EAGAIN, EIO, ELOOP, ENOENT, ENOTDIR, ENOSYS
; mt_safe: false
; as_safe: false
; oracles: reference:c17-temporary-name, reference:linux-entropy, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Generate at least TMP_MAX distinct names per process in the fixed /tmp directory.
; semantics: Use process identity, a monotonically increasing success counter, and Linux random bytes.
; semantics: Check the candidate with lstat, including dangling links. Leave creation and reservation to the caller.
; semantics: Write the result to the caller buffer or static storage only on success. Preserve errno on success.
; semantics: After TMP_MAX successes, report EAGAIN without publishing another name.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tmpnam:function
extern __al_lock:function
extern __al_unlock:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __errno_location:function
extern getpid:function
extern lstat:function
extern memcpy:function
extern stat:function

section .text.tmpnam alloc exec nowrite progbits
tmpnam:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, rdi
    call __errno_location
    mov r15d, [rax]
    lea rdi, [rel name_lock]
    call __al_lock

    cmp dword [rel sequence], 32767
    jae .exhausted
    lea rdi, [rel temporary_directory]
    lea rsi, [rel stat_record]
    call stat
    test eax, eax
    jnz .failure
    mov eax, [rel stat_record + 24]
    and eax, 0xf000               ; S_IFMT
    cmp eax, 0x4000               ; S_IFDIR
    jne .not_directory

    call getpid
    shl rax, 32
    mov r13d, [rel sequence]
    or r13, rax
    lea rbx, [rel working_name]
    mov r14d, 256
.entropy:
    mov qword [rsp], 0
    mov edi, 318                  ; __NR_getrandom
    lea rsi, [rel random_bytes]
    mov edx, 8
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, 8
    je .encode
    cmp rax, -4                   ; EINTR
    je .entropy
    cmp rax, -4095
    jae .translate
    mov rax, -5                   ; unexpected short entropy read
    jmp .translate

.encode:
    mov rax, r13
    lea rsi, [rbx + 8]
    lea rdx, [rel hex_digits]
    mov ecx, 32
.digit:
    mov rdi, rax
    shr rdi, 60
    mov dil, [rdx + rdi]
    mov [rsi], dil
    shl rax, 4
    inc rsi
    dec ecx
    cmp ecx, 16
    jne .more_digits
    mov rax, [rel random_bytes]
.more_digits:
    test ecx, ecx
    jnz .digit

    mov rdi, rbx
    lea rsi, [rel stat_record]
    call lstat
    test eax, eax
    jz .occupied
    call __errno_location
    cmp dword [rax], 2            ; ENOENT, the candidate is absent
    jne .failure
    inc dword [rel sequence]
    test r12, r12
    jnz .publish
    lea r12, [rel public_name]
.publish:
    mov rdi, r12
    mov rsi, rbx
    mov edx, 41
    call memcpy
    call __errno_location
    mov [rax], r15d
    jmp .done

.occupied:
    dec r14d
    jnz .entropy
.exhausted:
    mov rax, -11                  ; EAGAIN
    jmp .translate
.not_directory:
    mov rax, -20                  ; ENOTDIR
.translate:
    mov rdi, rax
    call __al_syscall_result
.failure:
    xor r12d, r12d
.done:
    lea rdi, [rel name_lock]
    call __al_unlock
    mov rax, r12
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.tmpnam alloc noexec nowrite progbits
temporary_directory: db "/tmp", 0
hex_digits: db "0123456789abcdef"

section .data.tmpnam alloc noexec write progbits
working_name: db "/tmp/oa-00000000000000000000000000000000", 0

section .bss.tmpnam alloc noexec write nobits align=8
random_bytes: resq 1
stat_record: resb 144
name_lock: resd 1
sequence: resd 1
public_name: resb 41

section .note.GNU-stack noalloc noexec nowrite progbits
