; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mktime
; header: time.h
; prototype: time_t mktime(struct tm *value)
; standard: C17 7.27.2.3
; deps: getenv, calloc, malloc, free, strlen, strcmp, memcpy, close, __errno_location
; errno: EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:gregorian-local
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Normalize the calendar fields into a local civil time. Ignore incoming weekday and year-day fields.
; semantics: Use the current zone and interpret negative tm_isdst as an unknown DST preference.
; semantics: Prefer a matching DST state when supplied. For an unspecified repeated time choose the earlier instant.
; semantics: Normalize an unspecified skipped time forward using the pre-transition offset.
; semantics: On success replace value with normalized fields and preserve errno. A successful timestamp may equal -1.
; semantics: On overflow return -1 with EOVERFLOW and leave value unchanged.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mktime:function
extern __al_civil_seconds:function
extern __al_mktime_pick:function
extern __al_zone_lock:data
extern __al_zone_acquire:function
extern __al_zone_publish:function
extern __al_unlock:function
extern __errno_location:function

section .text.mktime alloc exec nowrite progbits
mktime:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    call __errno_location
    mov r13, rax
    mov r14d, [rax]
    mov rdi, rbx
    call __al_civil_seconds
    mov r12, rax
    call __al_zone_acquire
    mov r15, rax
    mov rdi, rax
    mov rsi, r12
    movsxd rdx, dword [rbx + 32]
    test rdx, rdx
    js .unknown
    jz .pick
    mov edx, 1
    jmp .pick
.unknown:
    mov rdx, -1
.pick:
    call __al_mktime_pick
    mov r12, rax
    mov rdi, r15
    mov rsi, rax
    mov rdx, rbx
    call __al_zone_publish
    mov r15, rax
    lea rdi, [rel __al_zone_lock]
    call __al_unlock
    mov rax, -1
    test r15, r15
    jz .done
    mov [r13], r14d
    mov rax, r12
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
