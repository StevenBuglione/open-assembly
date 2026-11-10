; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_key_delete
; header: pthread.h
; prototype: int pthread_key_delete(pthread_key_t key)
; standard: POSIX.1-2024 XSH pthread_key_delete
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:thread-specific-data
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Invalidate the key generation without invoking a destructor.
; semantics: Return EINVAL for an unavailable key. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_key_delete:function
extern __al_tsd_keys:data
extern __al_tsd_lock:data
extern __al_lock:function
extern __al_unlock:function

section .text.pthread_key_delete alloc exec nowrite progbits
pthread_key_delete:
    mov edi, edi
    cmp edi, 128
    jae .invalid
    push rbx
    mov ebx, edi
    shl rbx, 4
    lea rdi, [rel __al_tsd_lock]
    call __al_lock
    lea rcx, [rel __al_tsd_keys]
    mov rax, [rcx + rbx]
    test al, 1
    jz .missing
    inc rax
    mov [rcx + rbx], rax
    mov qword [rcx + rbx + 8], 0
    xor ebx, ebx
    jmp .done
.missing:
    mov ebx, 22                    ; EINVAL
.done:
    lea rdi, [rel __al_tsd_lock]
    call __al_unlock
    mov eax, ebx
    pop rbx
    ret
.invalid:
    mov eax, 22                    ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
