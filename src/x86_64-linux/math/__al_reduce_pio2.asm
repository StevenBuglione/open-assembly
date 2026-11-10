; Reduce |x|=rdi*2^rsi. rdx/rcx/r8 are Q256 output, product, and 18-word multiply scratch.
; For r9=1, rdi points to a normalized bignum instead of a scalar.
bits 64
default rel

global __al_reduce_pio2:function
extern __al_big_mul_u64:function
extern __al_big_multiply:function
extern __al_big_bits:function
extern __al_big_right_sticky:function
extern __al_big_copy:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_sub:function
extern __al_fixed_mul256:function

section .text.__al_reduce_pio2 alloc exec nowrite progbits
__al_reduce_pio2:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rsi
    mov r12, rdi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov qword [rsp + 8], -256
    test r9d, r9d
    jnz .multiply_big
    cmp rbx, -64
    jl .unreduced

    mov rdi, r14
    lea rsi, [rel two_over_pi]
    mov rdx, r12
    call __al_big_mul_u64
    jmp .fraction_window
.multiply_big:
    mov rdi, r14
    lea rsi, [rel two_over_pi]
    mov rdx, r12
    call __al_big_multiply
    jmp .raw_fraction
.fraction_window:
    mov rdi, r14
    mov esi, 16640                ; D minus the 256 retained fractional bits
    sub rsi, rbx
    call __al_big_right_sticky
    mov r10, [r14]
    xor eax, eax
    cmp r10, 8
    jbe .fraction
    mov eax, [r14 + 40]
    and eax, 3
    mov r10d, 8
.fraction:
    mov [rsp], eax                ; integer portion modulo four
    mov dword [rsp + 4], 0
    cmp r10, 8
    jb .trim
    test dword [r14 + 36], 0x80000000
    jz .trim
    inc eax
    and eax, 3
    mov [rsp], eax
    mov dword [rsp + 4], 1       ; subtraction of a larger multiple of pi/2

.trim:
    test r10, r10
    jz .copy_fraction
    cmp dword [r14 + r10*4 + 4], 0
    jne .copy_fraction
    dec r10
    jmp .trim
.copy_fraction:
    mov [r14], r10
    mov rdi, r13
    mov rsi, r14
    call __al_big_copy
    cmp dword [rsp + 4], 0
    je .radians

    ; Magnitude of a negative fractional residual is one minus the
    ; retained fractional field. The reduction certificate bounds the
    ; omitted tail well below this 256-bit grid.
    mov rdi, r14
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    mov rdi, r14
    mov esi, 256
    call __al_big_left
    mov rdi, r14
    mov rsi, r13
    call __al_big_sub
    mov rdi, r13
    mov rsi, r14
    call __al_big_copy
.radians:
    mov rdi, r13
    mov rsi, r13
    lea rdx, [rel half_pi]
    mov rcx, r15
    call __al_fixed_mul256
    mov eax, [rsp]
    mov edx, [rsp + 4]
    jmp .done

.raw_fraction:
    ; Inspect the rounded quadrant before dropping the integer field.
    ; Keep small remainders on a separate scale for complex power.
    mov rax, 16896
    sub rax, rbx
    mov rbx, rax
    dec rax
    mov r9, rax
    shr r9, 5
    mov ecx, eax
    and ecx, 31
    xor eax, eax
    cmp r9, [r14]
    jae .quadrant_bits
    mov eax, [r14 + r9*4 + 8]
    inc r9
    cmp r9, [r14]
    jae .shift_quadrant
    mov r10d, [r14 + r9*4 + 8]
    shl r10, 32
    or rax, r10
.shift_quadrant:
    shr rax, cl
.quadrant_bits:
    mov edx, eax
    and edx, 1
    add eax, edx
    shr eax, 1
    and eax, 3
    mov [rsp], eax
    mov [rsp + 4], edx

    mov r10, rbx
    shr r10, 5
    mov ecx, ebx
    and ecx, 31
    cmp r10, [r14]
    jae .raw_remainder
    test ecx, ecx
    jz .trim_raw
    mov eax, 1
    shl eax, cl
    dec eax
    and [r14 + r10*4 + 8], eax
    inc r10
.trim_raw:
    test r10, r10
    jz .save_raw_count
    cmp dword [r14 + r10*4 + 4], 0
    jne .save_raw_count
    dec r10
    jmp .trim_raw
.save_raw_count:
    mov [r14], r10
.raw_remainder:
    cmp dword [rsp + 4], 0
    je .copy_raw_remainder
    mov rdi, r13
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    mov rdi, r13
    mov rsi, rbx
    call __al_big_left
    mov rdi, r13
    mov rsi, r14
    call __al_big_sub
    jmp .raw_scale
.copy_raw_remainder:
    mov rdi, r13
    mov rsi, r14
    call __al_big_copy
.raw_scale:
    mov rdi, r13
    call __al_big_bits
    mov rcx, rax
    sub rcx, rbx
    cmp rcx, -79
    jl .scaled_radians
    mov rdi, r13
    mov rsi, rbx
    sub rsi, 256
    call __al_big_right_sticky
    jmp .radians
.scaled_radians:
    sub rax, 256
    jle .raw_radians
    mov rdi, r13
    mov rsi, rax
    mov [rsp + 8], rax
    call __al_big_right_sticky
    jmp .multiply_raw_radians
.raw_radians:
    mov qword [rsp + 8], 0
.multiply_raw_radians:
    sub [rsp + 8], rbx
    sub qword [rsp + 8], 256
    mov rdi, r14
    mov rsi, r13
    lea rdx, [rel half_pi]
    call __al_big_multiply
    mov rdi, r13
    mov rsi, r14
    call __al_big_copy
    mov eax, [rsp]
    mov edx, [rsp + 4]
    jmp .done

.unreduced:
    mov rdi, r13
    mov rsi, r12
    xor edx, edx
    call __al_big_init128
    mov rdi, r13
    lea esi, [rbx + 256]
    call __al_big_left
    xor eax, eax
    xor edx, edx
.done:
    mov rcx, [rsp + 8]
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_reduce_pio2 alloc noexec nowrite progbits align=8
; Floor of (2/pi) * 2^16896, verified by tools/math-range-certificate.
two_over_pi:
    dq 528
    dd 0x365895b7, 0x7e8a31bb, 0xf8563aeb, 0x6052dd34, 0xc3a734ba, 0x47270bab
    dd 0x4ceab2bb, 0xa74b38fc, 0x64a8f1ae, 0x89b295f3, 0x71e0e13f, 0x4d590180
    dd 0xd255f4fc, 0x34007700, 0x5b2746ed, 0x825c326b, 0x8d39a9b8, 0x6ded727a
    dd 0xc4a1a283, 0x36169f3a, 0x61dd9602, 0xb5d6df82, 0x19a5abf9, 0x4d7e6f51
    dd 0x212a9db5, 0x561408f1, 0x8ef5a7e7, 0x7e32b90f, 0x8270237c, 0xca984e63
    dd 0x09209f44, 0xce68b4ed, 0x9529a828, 0x6919949a, 0xdd27dde1, 0xdc51a463
    dd 0x3d0b7cbd, 0xa365b193, 0xbf920d2b, 0x268a67f7, 0x3ac4eaf4, 0x7bdbe5c2
    dd 0x78e4c4a8, 0x2688893c, 0x12bf4390, 0x2a1a2c80, 0x61107b4c, 0x94792c87
    dd 0x853b8621, 0xc5476243, 0xae5adb86, 0xd3cfc50f, 0xfa94c5c1, 0x8a59c52b
    dd 0xffca0f1c, 0xfb49e956, 0xd49ee540, 0x39e6e389, 0x2a218347, 0x086e5986
    dd 0x2b55ba41, 0xf6552388, 0x7aacbaa2, 0x5ea4677b, 0x9dfe5fd4, 0x42eb67df
    dd 0xdc3a74e1, 0x9f405547, 0x21cf98dc, 0x214a827b, 0xd1f9b392, 0x974c8836
    dd 0x65a7887f, 0x0569f0b2, 0x0ed7a948, 0x51b13399, 0xe7caa40d, 0x3826829b
    dd 0x67aae855, 0xad38dc93, 0x36228922, 0x56ae79e5, 0x864ffc06, 0xc0549efa
    dd 0x59987ad9, 0x2c21d7f3, 0xa118af46, 0xdddd1c2d, 0x3ed84871, 0xc6835110
    dd 0x61bc57e1, 0x17c99b58, 0xef3392b8, 0xdd9b8e67, 0x5de8605e, 0xeebc34cc
    dd 0xfc2dbc34, 0xb5f4f5cb, 0x0f117f11, 0x26ee523f, 0x9569605a, 0xb8701a64
    dd 0xc096190b, 0x552ad6c6, 0xcc2254dc, 0x538c994e, 0x1c2f84b4, 0x6a4afbd8
    dd 0x1b0afc81, 0x2138c8d9, 0x61392f44, 0xefc9352e, 0xb4fcd1ee, 0x84d4e9a9
    dd 0x8e2c86e2, 0xf4e16d3b, 0x4a0bfdfb, 0x3ecc5f11, 0x5e6b9c2a, 0xb920d6aa
    dd 0x2ce3ce99, 0x576f8956, 0x2d891234, 0xb40ecccf, 0xa8d8b5a8, 0x36c59456
    dd 0x31c36ef1, 0x97c427a8, 0xb9ba8bfc, 0xd913d9ec, 0x4556367e, 0xbefdfdef
    dd 0x01767a9f, 0x667e1629, 0x0c188194, 0x742c150d, 0x7de58ad8, 0x24ba7460
    dd 0xb70db2e2, 0xc9b55100, 0xdf7329ba, 0xc6a9cff7, 0x723e6a11, 0x9d6ecd7b
    dd 0x7cb2ad6b, 0x0893745d, 0xc6fdb0c1, 0xffe26a6e, 0xe0088dd7, 0x35916fc5
    dd 0xe7ca7c22, 0xfd29f3d6, 0x87c461e9, 0x0e423e1c, 0x2eaced44, 0xc6926e5d
    dd 0x55f5bdd2, 0x18465f75, 0x3c3aba46, 0x6913daf0, 0x5877c5e3, 0xc397a4d4
    dd 0x9b31bed9, 0x647cd864, 0x41f3e8de, 0x4ec8cad6, 0x45e0fa29, 0x7bdc06cc
    dd 0xa33540c0, 0x72953b06, 0x0efb1ec3, 0xb2485551, 0xb08cd0c0, 0x6b0701ac
    dd 0xbf11654d, 0xdec9f560, 0x86dd71b6, 0x800120cc, 0x3f149538, 0x5f57a4b1
    dd 0x0da63a20, 0xc7f48d4d, 0x985ad795, 0x4fbcf82d, 0x2a4a5ac4, 0x4f6a68a8
    dd 0x059ebfb9, 0x897bfef3, 0xb6256b34, 0x872afdda, 0x4196debe, 0x640b148d
    dd 0x7f8607e1, 0x0027f014, 0x17552e55, 0xca5c6a08, 0x17ab81a2, 0xc1db9bbd
    dd 0x11d0be7d, 0xf9b4cbda, 0x0a5d2f42, 0x20d3a2b3, 0xcd4f99a5, 0x2d408da0
    dd 0x2780030c, 0x698f77ff, 0x21f716e4, 0x08d4b1ea, 0x32a1a4b7, 0xc3b21d36
    dd 0x5da92e85, 0x6e13e430, 0xc4f1335f, 0x50b7d51e, 0x52993755, 0xe0566b01
    dd 0xb9496170, 0x1262845c, 0x476f21d2, 0x05a0dd5a, 0x00a4e46c, 0xfd6cbfa2
    dd 0xc9b8cb30, 0x6125ce70, 0x432dc735, 0x8416df30, 0xbf3148d7, 0x3967955b
    dd 0xb36e6d8f, 0xbd4dafe7, 0x86182aea, 0x28336761, 0x87fd073e, 0x156e85ff
    dd 0x0670803e, 0x76e4fca9, 0xfdbe896c, 0xfafedb89, 0xb7dcfde5, 0x2a12162d
    dd 0x76a1597b, 0x07da0eaa, 0x7e804ba7, 0xb6b42d29, 0x53ad0457, 0x9aaf0093
    dd 0x2a3a25a3, 0xc790b6db, 0x6dded01f, 0xddbc5c3f, 0xf0ac9aec, 0xf480c62f
    dd 0x86a05df7, 0xadc3da48, 0xc1998c77, 0xd12df1b1, 0xcf761d02, 0xba66aacf
    dd 0x9bb7dac4, 0xebef584a, 0xe26e6f00, 0x8953a6c6, 0x8b7b7217, 0x76f92304
    dd 0x0bcd785b, 0xc1d20f3f, 0xa8654fa5, 0x331aaaf0, 0xbe13b523, 0xe9424ea4
    dd 0x5709cd36, 0xb33d8f1b, 0x1de4d9a4, 0x040622fa, 0x8c6615cb, 0x3080abf6
    dd 0x75df9328, 0xf96af3be, 0x3aff47b9, 0x29bf5657, 0x05ed3065, 0x664d64b7
    dd 0x00dafb0c, 0x15dfa1ae, 0xaba1ae31, 0x6837dbfc, 0x8c76528b, 0xde6319ef
    dd 0xab6842dd, 0xa9e69492, 0xcd37a736, 0xc6a5ca4e, 0x92f54bad, 0x5bc3d8c4
    dd 0x3915200c, 0x316d07b4, 0x8c402b99, 0x03f6f009, 0x56c0833f, 0x9c7a2d97
    dd 0x5c4dc26d, 0xedaf1226, 0xc2a31dae, 0x0eaa3a51, 0x3b091a94, 0x76836433
    dd 0x0a2f2689, 0x22dbaa14, 0xf6b6ebbb, 0xd2277549, 0x401004f2, 0xb989c7bd
    dd 0x62bbcb61, 0x185915a5, 0x0f903876, 0x6c4bffdb, 0xe80faf80, 0x921110d8
    dd 0x5c93805a, 0x3715a080, 0x3bdf082b, 0xdde7b717, 0x39928c70, 0xde41319d
    dd 0x438c860d, 0x3fa3fd94, 0x83dd9797, 0x663de064, 0x71ea49c2, 0x27fc00a8
    dd 0x777030f3, 0xa4049407, 0x50722cbe, 0x9089d988, 0x14ad6ae2, 0xacccc654
    dd 0x1d296996, 0x6b49ba27, 0x17f9877d, 0xb4c576ea, 0x045ddb3b, 0x9d072750
    dd 0x2ad56614, 0x090b69f5, 0x6e5445c1, 0x5bd4714e, 0x4832754c, 0x10d86d32
    dd 0x55c06437, 0x89852952, 0x035d407f, 0xb25f3edd, 0x4bf56863, 0x3398207e
    dd 0xd1f20acf, 0x91b45153, 0xa6948ef6, 0x6eef169f, 0x7df77248, 0x24d6bda6
    dd 0x4702e774, 0xee2c90aa, 0x68084b58, 0x30010c0d, 0x74f71c05, 0x25318d39
    dd 0x9f09e5bc, 0x5d8db815, 0x42727132, 0x486ca467, 0xfdbbb49a, 0x365f5f0e
    dd 0x996bed88, 0xe6e29731, 0x9794e884, 0x4189dff4, 0x1679e279, 0x96cb314a
    dd 0x721fe76b, 0x550c90a7, 0x2f327b6d, 0x2ec29247, 0x20ab9fb5, 0x9c12887b
    dd 0x2ef3450b, 0x71c1b309, 0x9405933e, 0xb328f8c7, 0xf1ecc3e7, 0xf53e1380
    dd 0x1eeece70, 0xbe00cc94, 0x10d5fdfc, 0xd4e54929, 0x1700ad43, 0x91b24df3
    dd 0xc444c5c8, 0x4612c459, 0x1426049b, 0xc277c912, 0xa8288d61, 0x36d9cad2
    dd 0x2645ca55, 0x818d67c1, 0xcbbff4ef, 0x6f63a62d, 0x8cafbdd7, 0x78738a5a
    dd 0xa3883c61, 0x775c83c2, 0xf2a6067f, 0x0ab499d3, 0x616aa428, 0x425faece
    dd 0x10d8ddaa, 0x4a48d367, 0xf2e91e43, 0xf57fb0ad, 0x48835b8e, 0x62128301
    dd 0x1834132e, 0x1df35be0, 0x50c017a7, 0x08cb7de0, 0xcac616e3, 0x4d58e232
    dd 0xd2e88628, 0x9bde2822, 0xde3b5892, 0x5dd7de16, 0x366cd43f, 0xcdc4ef09
    dd 0x3260bfe6, 0x652289e8, 0xd87f7eb7, 0x9947fbac, 0x1e666157, 0xff319f6a
    dd 0xf1dfce19, 0x1f001b0a, 0x23545ab9, 0x24778ad6, 0x84a7cb23, 0xd9d63b38
    dd 0x175649c0, 0xb07ae715, 0xf87c6357, 0x64abd770, 0x764d2a9d, 0x1810a3fc
    dd 0x37f63ed7, 0xa7b4d555, 0x7cd2b497, 0x9b006233, 0x71e39ac6, 0x467d862d
    dd 0x2c5d000c, 0xc4ad414d, 0x9d19c3c2, 0x15c614b5, 0x2d30433b, 0xfa6ed577
    dd 0x7c7c246a, 0x87f12190, 0xcaf27f1d, 0x9f3a1f35, 0x6b1e5ef8, 0xc33d26ef
    dd 0x98327dbb, 0x32c2de4f, 0x3f7e33e8, 0xa5ff0705, 0x5719053e, 0xddaf44d1
    dd 0x8b961ca6, 0x8359c476, 0xdce8092a, 0x19c367cd, 0x8c6b47c4, 0x60e27bc0
    dd 0xca73a8c9, 0x06061556, 0x4d732731, 0x8dffd880, 0x14a06840, 0x6599855f
    dd 0x5ee61b08, 0xa9e39161, 0x9af4361d, 0xf0cfbc20, 0xfc7b6bab, 0x56033046
    dd 0x1f8d5d08, 0x6bfb5fb1, 0x8a5292ea, 0x3d0739f7, 0xebe5f17b, 0x7527bac7
    dd 0x9e5fea2d, 0x4f463f66, 0x27cb09b7, 0x6d367ecf, 0x5a0a6d1f, 0xef2f118b
    dd 0xde05980f, 0x1ff897ff, 0xbdf9283b, 0x9c845f8b, 0x835339f4, 0x3991d639
    dd 0xb45f7e41, 0xe99c7026, 0x2ebb4484, 0xe88235f5, 0xb129a73e, 0xfe1deb1c
    dd 0x09d1921c, 0x06492eea, 0x424dd2e0, 0xb7246e3a, 0xdebbc561, 0xfe5163ab
    dd 0x3c439041, 0xdb629599, 0xf534ddc0, 0xfc2757d1, 0x4e441529, 0xa2f9836e
; Floor of (pi/2) * 2^256, enclosed by directed MPFR bounds.
half_pi:
    dq 9
    dd 0x76273644, 0x04177d4c, 0x14cf98e8, 0x52049c11
    dd 0x01b839a2, 0x898cc517, 0x42d18469, 0x921fb544, 0x00000001

section .note.GNU-stack noalloc noexec nowrite progbits
