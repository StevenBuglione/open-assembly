; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: gmtime_r
; header: time.h
; prototype: struct tm *gmtime_r(const time_t *restrict timer, struct tm *restrict result)
; standard: POSIX.1-2024 XSH gmtime_r
; deps: __errno_location
; errno: EOVERFLOW
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:gregorian-utc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert signed seconds since the Unix epoch into UTC using a proleptic Gregorian calendar.
; semantics: Produce seconds, minutes, hours, day, zero-based month, year since 1900, weekday, and year day.
; semantics: Set DST and offset to zero and the zone abbreviation to UTC.
; semantics: Return result and preserve errno on success.
; semantics: If the year does not fit in tm_year, leave result unchanged and return null with EOVERFLOW.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global gmtime_r:function
extern __al_utc_convert:function

section .text.gmtime_r alloc exec nowrite progbits
gmtime_r:
    sub rsp, 8
    mov rdi, [rdi]
    call __al_utc_convert
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
