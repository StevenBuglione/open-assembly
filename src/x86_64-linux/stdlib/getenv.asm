; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getenv
; header: stdlib.h
; prototype: char *getenv(const char *name)
; standard: C17 7.22.4.6
; deps: -
; errno: -
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase3-contract
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Search the active environ array for an exact case-sensitive name followed by equals.
; semantics: Return a borrowed pointer to the value of the first matching entry, or NULL if absent.
; semantics: An empty name, a name containing equals, or a NULL name is treated as no match.
; semantics: Preserve errno. An environment mutation can invalidate a previously returned pointer.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getenv:function
extern environ:data
extern __al_env_lock:data
extern __al_env_name:function
extern __al_env_match:function
extern __al_lock:function
extern __al_unlock:function

section .text.getenv alloc exec nowrite progbits
getenv:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi                  ; name
    xor r14d, r14d                ; result
    xor esi, esi                  ; an equals sign is invalid in a name
    call __al_env_name
    test rax, rax
    jz .done
    mov r12, rax                  ; name length
    lea rdi, [rel __al_env_lock]
    call __al_lock
    mov r13, [rel environ]
    test r13, r13
    jz .unlock
.next:
    mov rdi, [r13]
    test rdi, rdi
    jz .unlock
    mov rsi, rbx
    mov rdx, r12
    call __al_env_match
    test rax, rax
    jnz .match
    add r13, 8
    jmp .next
.match:
    mov r14, rax
.unlock:
    lea rdi, [rel __al_env_lock]
    call __al_unlock
.done:
    mov rax, r14
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
