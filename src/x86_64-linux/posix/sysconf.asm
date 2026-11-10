; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sysconf
; header: unistd.h
; prototype: long sysconf(int name)
; standard: POSIX.1-2024 XSH sysconf
; deps: __errno_location
; errno: EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the process page size for _SC_PAGESIZE or _SC_PAGE_SIZE. Reject other selectors in this scope.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sysconf:function
extern __al_auxv:data
extern __al_syscall_result:function

section .text.sysconf alloc exec nowrite progbits
sysconf:
    movsxd rdi, edi
    cmp edi, 30                   ; _SC_PAGESIZE or _SC_PAGE_SIZE
    jne .invalid
    mov rcx, [rel __al_auxv]
.next:
    mov rax, [rcx]
    test rax, rax                 ; AT_NULL
    jz .invalid
    cmp rax, 6                    ; AT_PAGESZ
    je .found
    add rcx, 16
    jmp .next
.found:
    mov rax, [rcx + 8]
    test rax, rax
    jle .invalid
    ret

.invalid:
    sub rsp, 8
    mov rdi, -22                  ; EINVAL
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
