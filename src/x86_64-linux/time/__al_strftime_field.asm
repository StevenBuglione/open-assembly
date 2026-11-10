; Original C-locale strftime conversion. Inputs: cursor, reserved end,
; conversion character, and tm pointer. Return cursor or null.
bits 64
default rel

global __al_strftime_field:function
extern __al_strftime_render:function
extern __al_strftime_number:function
extern __al_iso_week:function

section .text.__al_strftime_field alloc exec nowrite progbits
__al_strftime_field:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rcx
    mov r14d, edx
    mov ecx, 2                   ; common magnitude width
    mov r8d, 48                  ; common zero padding
    cmp r14b, 65                ; A
    je .weekday_full
    cmp r14b, 97                ; a
    je .weekday_short
    cmp r14b, 66                ; B
    je .month_full
    cmp r14b, 98                ; b
    je .month_short
    cmp r14b, 104               ; h
    je .month_short
    cmp r14b, 67                ; C
    je .century
    cmp r14b, 100               ; d
    je .month_day
    cmp r14b, 101               ; e
    je .month_day_space
    cmp r14b, 103               ; g
    je .iso
    cmp r14b, 71                ; G
    je .iso
    cmp r14b, 72                ; H
    je .hour
    cmp r14b, 73                ; I
    je .hour_12
    cmp r14b, 106               ; j
    je .year_day
    cmp r14b, 109               ; m
    je .month
    cmp r14b, 77                ; M
    je .minute
    cmp r14b, 110               ; n
    je .newline
    cmp r14b, 112               ; p
    je .meridian
    cmp r14b, 83                ; S
    je .second
    cmp r14b, 116               ; t
    je .tab
    cmp r14b, 117               ; u
    je .weekday_iso
    cmp r14b, 85                ; U
    je .week_sunday
    cmp r14b, 86                ; V
    je .iso
    cmp r14b, 119               ; w
    je .weekday
    cmp r14b, 87                ; W
    je .week_monday
    cmp r14b, 121               ; y
    je .year_short
    cmp r14b, 89                ; Y
    je .year
    cmp r14b, 122               ; z
    je .zone_offset
    cmp r14b, 90                ; Z
    je .zone_name
    cmp r14b, 37                ; %
    je .percent
    cmp r14b, 99                ; c
    je .date_time
    cmp r14b, 68                ; D
    je .date_short
    cmp r14b, 120               ; x
    je .date_short
    cmp r14b, 70                ; F
    je .date_iso
    cmp r14b, 114               ; r
    je .time_12
    cmp r14b, 82                ; R
    je .time_short
    cmp r14b, 84                ; T
    je .time_24
    cmp r14b, 88                ; X
    je .time_24
    jmp .failure
.weekday_full:
    movsxd rdx, dword [r13 + 24]
    cmp rdx, 6
    ja .failure
    imul rdx, 10
    lea rax, [rel weekdays_full]
    add rdx, rax
    jmp .text
.weekday_short:
    movsxd rdx, dword [r13 + 24]
    cmp rdx, 6
    ja .failure
    lea rax, [rel weekdays_short]
    lea rdx, [rax + rdx*4]
    jmp .text
.month_full:
    movsxd rdx, dword [r13 + 16]
    cmp rdx, 11
    ja .failure
    imul rdx, 10
    lea rax, [rel months_full]
    add rdx, rax
    jmp .text
.month_short:
    movsxd rdx, dword [r13 + 16]
    cmp rdx, 11
    ja .failure
    lea rax, [rel months_short]
    lea rdx, [rax + rdx*4]
    jmp .text
.month_day_space:
    mov r8d, 32
.month_day:
    movsxd rdx, dword [r13 + 12]
    jmp .number
.hour:
    movsxd rdx, dword [r13 + 8]
    jmp .number
.hour_12:
    movsxd rdx, dword [r13 + 8]
    cmp rdx, 23
    ja .failure
    test edx, edx
    jz .hour_12_at_midnight
    cmp edx, 12
    jbe .number
    sub edx, 12
    jmp .number
.hour_12_at_midnight:
    mov edx, 12
    jmp .number
.year_day:
    movsxd rdx, dword [r13 + 28]
    inc rdx
    mov ecx, 3
    jmp .number
.month:
    movsxd rdx, dword [r13 + 16]
    inc rdx
    jmp .number
.minute:
    movsxd rdx, dword [r13 + 4]
    jmp .number
.second:
    movsxd rdx, dword [r13]
    jmp .number
.meridian:
    lea rdx, [rel am]
    cmp dword [r13 + 8], 12
    jl .text
    lea rdx, [rel pm]
    jmp .text
.weekday_iso:
    movsxd rdx, dword [r13 + 24]
    test edx, edx
    jnz .weekday_number
    mov edx, 7
    jmp .weekday_number
.weekday:
    movsxd rdx, dword [r13 + 24]
.weekday_number:
    mov ecx, 1
    jmp .number
.week_monday:
    movsxd rax, dword [r13 + 24]
    dec rax
    jns .week_index
    mov eax, 6
    jmp .week_index
.week_sunday:
    movsxd rax, dword [r13 + 24]
.week_index:
    movsxd r9, dword [r13 + 28]
    add r9, 7
    sub r9, rax
    mov rax, r9
    cqo
    mov r9d, 7
    idiv r9
    mov rdx, rax
    jmp .number
.iso:
    movsxd rdi, dword [r13 + 20]
    add rdi, 1900
    movsxd rsi, dword [r13 + 28]
    cmp rsi, 365
    ja .failure
    movsxd rdx, dword [r13 + 24]
    cmp rdx, 6
    ja .failure
    call __al_iso_week
    mov ecx, 2
    mov r8d, 48
    cmp r14b, 86                 ; V
    je .number
    cmp r14b, 103                ; g
    je .year_remainder
    mov ecx, 4
    mov rdx, rax
    jmp .number
.year:
    movsxd rdx, dword [r13 + 20]
    add rdx, 1900
    mov ecx, 4
    jmp .number
.century:
    movsxd rax, dword [r13 + 20]
    add rax, 1900
    cqo
    mov r9d, 100
    idiv r9
    mov rdx, rax
    jmp .number
.year_short:
    movsxd rax, dword [r13 + 20]
    add rax, 1900
.year_remainder:
    cqo
    mov r9d, 100
    idiv r9
    test rdx, rdx
    jns .number
    add rdx, 100
.number:
    mov rdi, rbx
    mov rsi, r12
    call __al_strftime_number
    jmp .return
.zone_name:
    cmp dword [r13 + 32], 0
    jl .empty
    mov rdx, [r13 + 48]
    test rdx, rdx
    jz .empty
    jmp .text
.zone_offset:
    cmp dword [r13 + 32], 0
    jl .empty
    mov rax, [r13 + 40]
    mov r11d, 43
    test rax, rax
    jns .zone_magnitude
    neg rax
    mov r11d, 45
.zone_magnitude:
    cmp rax, 360000
    jae .empty
    lea r8, [rbx + 5]
    cmp r8, r12
    ja .failure
    mov byte [rbx], r11b
    mov r9d, 60
    xor edx, edx
    div r9                       ; discard subminute seconds
    xor edx, edx
    div r9                       ; hours and remaining minutes
    mov rcx, rdx
    mov r9d, 10
    xor edx, edx
    div r9
    add al, 48
    add dl, 48
    mov [rbx + 1], al
    mov [rbx + 2], dl
    mov rax, rcx
    xor edx, edx
    div r9
    add al, 48
    add dl, 48
    mov [rbx + 3], al
    mov [rbx + 4], dl
    mov rax, r8
    jmp .return
.newline:
    mov edx, 10
    jmp .byte
.tab:
    mov edx, 9
    jmp .byte
.percent:
    mov edx, 37
.byte:
    cmp rbx, r12
    jae .failure
    mov [rbx], dl
    lea rax, [rbx + 1]
    jmp .return
.text:
    mov rax, rbx
.text_byte:
    mov cl, [rdx]
    test cl, cl
    jz .return
    cmp rax, r12
    jae .failure
    mov [rax], cl
    inc rdx
    inc rax
    jmp .text_byte
.date_time:
    lea rdx, [rel format_date_time]
    jmp .render
.date_short:
    lea rdx, [rel format_date_short]
    jmp .render
.date_iso:
    lea rdx, [rel format_date_iso]
    jmp .render
.time_12:
    lea rdx, [rel format_time_12]
    jmp .render
.time_short:
    lea rdx, [rel format_time_short]
    jmp .render
.time_24:
    lea rdx, [rel format_time_24]
.render:
    mov rdi, rbx
    mov rsi, r12
    mov rcx, r13
    call __al_strftime_render
    jmp .return
.empty:
    mov rax, rbx
    jmp .return
.failure:
    xor eax, eax
.return:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_strftime_field alloc noexec nowrite progbits
am: db "AM", 0
pm: db "PM", 0
format_date_time: db "%a %b %e %H:%M:%S %Y", 0
format_date_short: db "%m/%d/%y", 0
format_date_iso: db "%Y-%m-%d", 0
format_time_12: db "%I:%M:%S %p", 0
format_time_short: db "%H:%M", 0
format_time_24: db "%H:%M:%S", 0
weekdays_full:
    db "Sunday", 0, 0, 0, 0
    db "Monday", 0, 0, 0, 0
    db "Tuesday", 0, 0, 0
    db "Wednesday", 0
    db "Thursday", 0, 0
    db "Friday", 0, 0, 0, 0
    db "Saturday", 0, 0
weekdays_short:
    db "Sun", 0
    db "Mon", 0
    db "Tue", 0
    db "Wed", 0
    db "Thu", 0
    db "Fri", 0
    db "Sat", 0
months_full:
    db "January", 0, 0, 0
    db "February", 0, 0
    db "March", 0, 0, 0, 0, 0
    db "April", 0, 0, 0, 0, 0
    db "May", 0, 0, 0, 0, 0, 0, 0
    db "June", 0, 0, 0, 0, 0, 0
    db "July", 0, 0, 0, 0, 0, 0
    db "August", 0, 0, 0, 0
    db "September", 0
    db "October", 0, 0, 0
    db "November", 0, 0
    db "December", 0, 0
months_short:
    db "Jan", 0
    db "Feb", 0
    db "Mar", 0
    db "Apr", 0
    db "May", 0
    db "Jun", 0
    db "Jul", 0
    db "Aug", 0
    db "Sep", 0
    db "Oct", 0
    db "Nov", 0
    db "Dec", 0

section .note.GNU-stack noalloc noexec nowrite progbits
