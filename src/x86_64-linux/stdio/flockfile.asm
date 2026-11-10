; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: flockfile
; header: stdio.h
; prototype: void flockfile(FILE *stream)
; standard: POSIX.1-2024 XSH flockfile
; deps: __errno_location
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:stream-ownership
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Acquire exclusive ownership shared by explicit and implicit operations on the stream.
; semantics: Recursive acquisitions by the same owner increment a depth count and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global flockfile:function
extern __al_stream_lock:function

section .text.flockfile alloc exec nowrite progbits
flockfile:
    sub rsp, 8
    call __al_stream_lock
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
