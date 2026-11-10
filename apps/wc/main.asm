; Original C-locale byte, line, and word counter.
bits 64
default rel

global main:function
extern stdin:data
extern stdout:data
extern stderr:data
extern fopen:function
extern fread:function
extern ferror:function
extern fclose:function
extern fflush:function
extern fputs:function
extern fputc:function
extern isspace:function
extern printf:function
extern perror:function

section .text.main alloc exec nowrite progbits
main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    movsxd r12, edi
    dec r12                      ; remaining argv entries
    lea rbx, [rsi + 8]
    xor r13d, r13d                ; selected lines, words, bytes
.options:
    test r12, r12
    jz .start
    mov rax, [rbx]
    cmp byte [rax], 45
    jne .start
    cmp byte [rax + 1], 0
    je .start
    cmp byte [rax + 1], 45
    jne .option_chars
    cmp byte [rax + 2], 0
    jne .bad_option
    add rbx, 8
    dec r12
    jmp .start
.option_chars:
    inc rax
.next_option:
    movzx ecx, byte [rax]
    test ecx, ecx
    jz .consume_option
    cmp ecx, 108                  ; l
    je .lines
    cmp ecx, 119                  ; w
    je .words
    cmp ecx, 99                   ; c
    jne .bad_option
    or r13d, 4
    jmp .more_options
.lines:
    or r13d, 1
    jmp .more_options
.words:
    or r13d, 2
.more_options:
    inc rax
    jmp .next_option
.consume_option:
    add rbx, 8
    dec r12
    jmp .options
.bad_option:
    lea rdi, [rel option_error]
    mov rsi, [rel stderr]
    call fputs
    mov dword [rel status], 1
    jmp .done

.start:
    test r13d, r13d
    jnz .operands_ready
    mov r13d, 7
.operands_ready:
    mov [rel operand_count], r12
    test r12, r12
    jnz .operand
    xor r15d, r15d                ; implicit stdin has no printed name
    jmp .standard_input
.operand:
    mov r15, [rbx]
    add rbx, 8
    dec r12
    cmp byte [r15], 45
    jne .open
    cmp byte [r15 + 1], 0
    je .standard_input
.open:
    mov rdi, r15
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .input_error
    mov r14, rax
    jmp .reset_counts
.standard_input:
    mov r14, [rel stdin]
.reset_counts:
    mov qword [rel counts], 0
    mov qword [rel counts + 8], 0
    mov qword [rel counts + 16], 0
    mov byte [rel in_word], 0
.read:
    lea rdi, [rel buffer]
    mov esi, 1
    mov edx, 4096
    mov rcx, r14
    call fread
    test rax, rax
    jz .finish_input
    add [rel counts + 16], rax
    mov [rel remaining], rax
    lea rax, [rel buffer]
    mov [rel cursor], rax
.byte:
    mov rax, [rel cursor]
    movzx edi, byte [rax]
    cmp edi, 10
    jne .space_check
    inc qword [rel counts]
.space_check:
    call isspace
    test eax, eax
    jnz .separator
    cmp byte [rel in_word], 0
    jne .next_byte
    inc qword [rel counts + 8]
    mov byte [rel in_word], 1
    jmp .next_byte
.separator:
    mov byte [rel in_word], 0
.next_byte:
    inc qword [rel cursor]
    dec qword [rel remaining]
    jnz .byte
    jmp .read
.finish_input:
    mov rdi, r14
    call ferror
    mov [rsp], eax
    test eax, eax
    jz .close_input
    mov rdi, r15
    test rdi, rdi
    jnz .read_error
    lea rdi, [rel program]
.read_error:
    call perror
    mov dword [rel status], 1
.close_input:
    cmp r14, [rel stdin]
    je .summarize
    mov rdi, r14
    call fclose
    test eax, eax
    jnz .input_error
.summarize:
    cmp dword [rsp], 0
    jne .after_print
    mov rax, [rel counts]
    add [rel totals], rax
    mov rax, [rel counts + 8]
    add [rel totals + 8], rax
    mov rax, [rel counts + 16]
    add [rel totals + 16], rax
    lea rax, [rel counts]
    mov [rel printed_values], rax
    jmp .print
.input_error:
    mov rdi, r15
    call perror
    mov dword [rel status], 1
    jmp .after_print

.print:
    xor r14d, r14d                ; count index
    mov byte [rel printed_count], 0
.field:
    mov ecx, r14d
    mov eax, 1
    shl eax, cl
    test eax, r13d
    jz .next_field
    lea rsi, [rel empty]
    cmp byte [rel printed_count], 0
    je .count_value
    lea rsi, [rel space]
.count_value:
    mov rax, [rel printed_values]
    mov rdx, [rax + r14*8]
    lea rdi, [rel field_format]
    xor eax, eax
    call printf
    test eax, eax
    js .output_error
    mov byte [rel printed_count], 1
.next_field:
    inc r14d
    cmp r14d, 3
    jb .field
    test r15, r15
    jz .newline
    lea rdi, [rel name_format]
    mov rsi, r15
    xor eax, eax
    call printf
    jmp .print_result
.newline:
    mov edi, 10
    mov rsi, [rel stdout]
    call fputc
.print_result:
    test eax, eax
    js .output_error
.after_print:
    test r12, r12
    jnz .operand
    cmp qword [rel operand_count], 1
    jbe .flush
    mov qword [rel operand_count], 0
    lea r15, [rel total_name]
    lea rax, [rel totals]
    mov [rel printed_values], rax
    jmp .print
.output_error:
    mov dword [rel status], 1
.flush:
    mov rdi, [rel stdout]
    call fflush
    test eax, eax
    jz .done
    mov dword [rel status], 1
.done:
    mov eax, [rel status]
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.wc alloc noexec nowrite progbits
program:
    db "wc", 0
read_mode:
    db "rb", 0
field_format:
    db "%s%zu", 0
name_format:
    db " %s", 10, 0
total_name:
    db "total", 0
option_error:
    db "wc: unsupported option", 10, 0
space:
    db " ", 0
empty:
    db 0

section .bss.wc alloc noexec write nobits align=16
buffer:
    resb 4096
counts:
    resq 3
totals:
    resq 3
remaining:
    resq 1
cursor:
    resq 1
printed_values:
    resq 1
operand_count:
    resq 1
status:
    resd 1
printed_count:
    resb 1
in_word:
    resb 1

section .note.GNU-stack noalloc noexec nowrite progbits
