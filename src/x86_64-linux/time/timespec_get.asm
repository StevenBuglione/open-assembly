; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: timespec_get
; header: time.h
; prototype: int timespec_get(struct timespec *ts, int base)
; standard: C17 7.27.2.5
; deps: clock_gettime
; errno: EFAULT, EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-time64
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: For TIME_UTC, publish realtime seconds and nanoseconds and return TIME_UTC on success.
; semantics: An unsupported base returns zero and leaves the output and errno unchanged.
; semantics: A failed clock operation returns zero and makes its errno available.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global timespec_get:function
extern clock_gettime:function

section .text.timespec_get alloc exec nowrite progbits
timespec_get:
    movsxd rsi, esi
    cmp esi, 1                    ; TIME_UTC
    jne .failure
    push rbp
    mov rbp, rsp
    mov rsi, rdi
    xor edi, edi                  ; CLOCK_REALTIME
    call clock_gettime
    pop rbp
    test eax, eax
    jnz .failure
    mov eax, 1
    ret
.failure:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
