; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mremap
; header: sys/mman.h
; prototype: void *mremap(void *old_address, size_t old_length, size_t new_length, int flags, ...)
; standard: Extension ABI mremap
; deps: __errno_location
; errno: EAGAIN, EFAULT, EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: ecx:s32
; variadic: true
; semantics: Resize or move a mapping. Read the optional new address only when MREMAP_FIXED is set.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mremap:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.mremap alloc exec nowrite progbits
mremap:
    sub rsp, 8
    mov qword [rsp], 0
    movsxd rcx, ecx
    xor r9d, r9d
    test ecx, 2                   ; MREMAP_FIXED
    jz .invoke
    mov r9, r8                    ; optional new address
.invoke:
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 25                   ; __NR_mremap
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
