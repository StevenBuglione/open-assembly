; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_getspecific
; header: pthread.h
; prototype: void *pthread_getspecific(pthread_key_t key)
; standard: POSIX.1-2024 XSH pthread_getspecific
; deps: pthread_self
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:thread-specific-data
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Return the calling thread's value for the current key generation.
; semantics: Return null for an unset or unavailable key. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_getspecific:function
extern pthread_self:function
extern __al_tsd_keys:data
extern __al_tsd_lock:data
extern __al_lock:function
extern __al_unlock:function

section .text.pthread_getspecific alloc exec nowrite progbits
pthread_getspecific:
    mov edi, edi
    cmp edi, 128
    jae .invalid
    push rbx
    push r12
    push r13
    mov ebx, edi
    shl rbx, 4
    call pthread_self
    mov r12, rax
    xor r13d, r13d
    lea rdi, [rel __al_tsd_lock]
    call __al_lock
    lea rcx, [rel __al_tsd_keys]
    mov rax, [rcx + rbx]
    test al, 1
    jz .done
    cmp rax, [r12 + rbx + 0x110]
    jne .done
    mov r13, [r12 + rbx + 0x118]
.done:
    lea rdi, [rel __al_tsd_lock]
    call __al_unlock
    mov rax, r13
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
