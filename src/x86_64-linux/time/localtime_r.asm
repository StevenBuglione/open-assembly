; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: localtime_r
; header: time.h
; prototype: struct tm *localtime_r(const time_t *restrict timer, struct tm *restrict result)
; standard: POSIX.1-2024 XSH localtime_r
; deps: getenv, calloc, malloc, free, strlen, strcmp, memcpy, close, __errno_location
; errno: EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:rfc9636
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert signed epoch seconds using the selected time zone and the proleptic Gregorian calendar.
; semantics: Select UTC for empty TZ or an unavailable or invalid zone. Use /etc/localtime when TZ is absent.
; semantics: Read the authoritative 64-bit TZif block when present and apply its trailing rule at and after the last transition.
; semantics: Publish local calendar fields, the DST indicator, the signed UTC offset, and the zone abbreviation.
; semantics: Return result and preserve errno on success. On overflow return null with EOVERFLOW and leave result unchanged.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global localtime_r:function
extern __al_zone_lock:data
extern __al_zone_acquire:function
extern __al_zone_publish:function
extern __al_unlock:function
extern __errno_location:function

section .text.localtime_r alloc exec nowrite progbits
localtime_r:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, [rdi]
    mov r12, rsi
    call __errno_location
    mov r13, rax
    mov r14d, [rax]
    call __al_zone_acquire
    mov rdi, rax
    mov rsi, rbx
    mov rdx, r12
    call __al_zone_publish
    mov rbx, rax
    lea rdi, [rel __al_zone_lock]
    call __al_unlock
    test rbx, rbx
    jz .done
    mov [r13], r14d
.done:
    mov rax, rbx
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
