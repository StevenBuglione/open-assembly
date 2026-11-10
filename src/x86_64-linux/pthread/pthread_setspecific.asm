; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_setspecific
; header: pthread.h
; prototype: int pthread_setspecific(pthread_key_t key, const void *value)
; standard: POSIX.1-2024 XSH pthread_setspecific
; deps: pthread_self
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:thread-specific-data
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Associate the value with the current key generation for the calling thread.
; semantics: Return EINVAL for an unavailable key. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_setspecific:function
extern pthread_self:function
extern __al_tsd_keys:data
extern __al_tsd_lock:data
extern __al_lock:function
extern __al_unlock:function

section .text.pthread_setspecific alloc exec nowrite progbits
pthread_setspecific:
    mov edi, edi
    cmp edi, 128
    jae .invalid
    push rbx
    push r12
    push r13
    mov ebx, edi
    shl rbx, 4
    mov r13, rsi
    call pthread_self
    mov r12, rax
    lea rdi, [rel __al_tsd_lock]
    call __al_lock
    lea rcx, [rel __al_tsd_keys]
    mov rax, [rcx + rbx]
    test al, 1
    jz .missing
    mov [r12 + rbx + 0x110], rax
    mov [r12 + rbx + 0x118], r13
    xor ebx, ebx
    jmp .done
.missing:
    mov ebx, 22                    ; EINVAL
.done:
    lea rdi, [rel __al_tsd_lock]
    call __al_unlock
    mov eax, ebx
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, 22                    ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
