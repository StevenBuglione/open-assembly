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
extern __al_syscall_result:function

section .text.gmtime_r alloc exec nowrite progbits
gmtime_r:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rsi                  ; public result, untouched until year fits
    mov rax, [rdi]
    cqo
    mov r9d, 86400
    idiv r9
    test rdx, rdx
    jns .split_day
    add rdx, 86400
    dec rax                       ; floor division for pre-epoch timestamps
.split_day:
    mov r13, rax                 ; days since 1970-01-01
    mov r14, rdx                 ; seconds within the day

    add rax, 719528               ; days since 0000-01-01
    cqo
    mov r9d, 146097              ; days in a Gregorian 400-year era
    idiv r9
    test rdx, rdx
    jns .split_era
    add rdx, 146097
    dec rax
.split_era:
    mov r15, rax                 ; era, starting at a year divisible by 400
    mov rbx, rdx                 ; day within era
    xor r8d, r8d                 ; inclusive low year, with known start
    mov r10d, 400                ; exclusive upper year
    xor ecx, ecx                 ; start day of the low year
.find_year:
    lea rsi, [r8 + 1]
    cmp rsi, r10
    jae .year_found
    lea rsi, [r8 + r10]
    shr rsi, 1                   ; midpoint year within the era, at least 1
    mov rdi, rsi
    imul rdi, 365
    lea rax, [rsi + 3]
    shr rax, 2
    add rdi, rax                 ; leap candidates preceding the year
    inc rdi                       ; year zero is divisible by 400
    lea rax, [rsi + 99]
    xor edx, edx
    mov r9d, 100
    div r9
    sub rdi, rax                 ; remove preceding century years
    cmp rdi, rbx
    ja .earlier
    mov r8, rsi
    mov rcx, rdi
    jmp .find_year
.earlier:
    mov r10, rsi
    jmp .find_year
.year_found:
    sub rbx, rcx                  ; zero-based year day
    imul r15, 400
    add r15, r8
    sub r15, 1900
    cmp r15, 2147483647
    jg .overflow
    cmp r15, -2147483648
    jl .overflow

    xor r9d, r9d                 ; leap-day adjustment for February
    test r8b, 3
    jnz .find_month
    cmp r8d, 100
    je .find_month
    cmp r8d, 200
    je .find_month
    cmp r8d, 300
    je .find_month
    mov r9d, 1
.find_month:
    mov rdi, rbx
    xor r10d, r10d
    lea rsi, [rel month_lengths]
.month:
    movzx edx, byte [rsi + r10]
    cmp r10d, 1
    jne .month_length
    add edx, r9d
.month_length:
    cmp rdi, rdx
    jb .date
    sub rdi, rdx
    inc r10d
    jmp .month
.date:
    inc edi                       ; one-based day of month
    mov [r12 + 12], edi
    mov [r12 + 16], r10d
    mov [r12 + 20], r15d
    mov [r12 + 28], ebx

    lea rax, [r13 + 4]           ; 1970-01-01 was Thursday
    cqo
    mov r9d, 7
    idiv r9
    test edx, edx
    jns .weekday
    add edx, 7
.weekday:
    mov [r12 + 24], edx
    mov rax, r14
    xor edx, edx
    mov r9d, 3600
    div r9
    mov [r12 + 8], eax
    mov rax, rdx
    xor edx, edx
    mov r9d, 60
    div r9
    mov [r12 + 4], eax
    mov [r12], edx
    mov qword [r12 + 32], 0      ; DST flag and padding
    mov qword [r12 + 40], 0      ; UTC offset
    lea rax, [rel utc_name]
    mov [r12 + 48], rax
    mov rax, r12
    jmp .done
.overflow:
    mov rdi, -75                  ; EOVERFLOW
    call __al_syscall_result
    xor eax, eax
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.gmtime_r alloc noexec nowrite progbits
month_lengths:
    db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
utc_name:
    db 'UTC', 0

section .note.GNU-stack noalloc noexec nowrite progbits
