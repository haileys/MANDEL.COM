use16
org 0x100

    fninit

    ; get current video mode
    mov ah, 0x0f
    int 0x10
    mov [old_vga_mode], al

    ; query info for the VESA mode we want
    mov ax, 0x4f01
    mov cx, target_vbe_mode
    mov di, vbe_mode_info
    int 0x10

    ; test error
    cmp ax, 0x004f
    jne exit

    ; set mode
    mov ax, 0x4f02
    mov bx, target_vbe_mode | (1 << 14) ; linear frame buffer
    int 0x10

    ; test error
    cmp ax, 0x4f
    jne exit

    ; read bits of mode info that we need
    mov ax, [vbe_mode_bytes_per_line]
    mov edi, [vbe_mode_framebuffer]

    ; set up gdt offset in gdtr
    mov eax, ds
    shl eax, 4
    add eax, gdt
    mov [gdtr.offset], eax

    ; load gdt to prepare to enter protected mode
    cli
    lgdt [gdtr]

    ; enter protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; load 32 bit descriptor into fs
    mov bx, 0x08
    mov fs, bx

    ; leave protected mode, now in unreal mode
    and al, ~1
    mov cr0, eax
L:
    mov word [y], 0
    mov cx, [vbe_mode_height]
row:
    push cx

    movzx eax, word [y]
    movzx edx, word [vbe_mode_bytes_per_line]
    mul edx
    mov edi, [vbe_mode_framebuffer]
    add edi, eax

    mov word [x], 0
    mov cx, [vbe_mode_width]
pix:
    push cx

    ; calculate imaginary component
    fld qword [y_siz]
    fidiv word [vbe_mode_height]
    fimul word [y]
    fadd qword [y_min]

    ; calculate real component
    fld qword [x_siz]
    fidiv word [vbe_mode_width]
    fimul word [x]
    fadd qword [x_min]
    ; C is st0 + st1*i

    fldz ; init z0
    fldz

    mov cx, [iter]
    movzx ecx, cx
mandel:
    ; LOOP INVARIANT:
    ; Z = st0 + st1*i
    ; C = st2 + st3*i

    ; Z^2 = st0^2 - st1^2 + 2*st0*st1*i

    fld st1 ; loads Z imag
    ; stack offset +1
    fld st1 ; loads Z real
    fmulp ; multiply
    fadd st0 ; double it
    ; st0 now contains Z^2 imag, stack offset +1

    fld st1
    fmul st0
    ; every stack offset is now +2
    fld st3
    fmul st0
    fsubp
    ; st0 now contains Z^2 real, stack offset + 2

    ; shift top two values up two slots:
    fstp st2
    fstp st2

    ; Z^2 = st0 + st1*i
    ; C = st2 + st3*i

    ; add C to Z^2
    fld st2
    faddp st1
    fld st3
    faddp st2

    ; Z^2 + C = st0 + st1*i
    ; C = st2 + st3*i

    ; Z = Z^2 + C
    ; loop invariant now holds

    ; calculate absolute value of Z and see if we've escaped:
    fld st1
    fmul st0
    ; stack offset + 1
    fld st1
    fmul st0
    faddp
    ; |Z|^2 = st0

    ; see if we've escaped
    fld qword [threshsq]
    fcomi

    ; pop twice to retain loop invariant
    fstp st0
    fstp st0

    ; bail out if we have escaped
    jb .end

    loop mandel
.end:
    ; clear FPU stack
    fstp st0
    fstp st0
    fstp st0
    fstp st0

    test cx, cx
    jz .black
    cmp cx, 16*1
    jl .c1
    cmp cx, 16*2
    jl .c2
    cmp cx, 16*3
    jl .c3
    cmp cx, 16*4
    jl .c4
    cmp cx, 16*5
    jl .c5
    jmp .c6
.black:
    xor eax, eax
    jmp .paint
.c1:
    mov eax, 0xff0000
    shl ecx, 12
    or eax, ecx
    jmp .paint
.c2:
    sub cl, 16*1
    not cl
    and cl, 15
    shl ecx, 20
    mov eax, 0x00ff00
    or eax, ecx
    jmp .paint
.c3:
    mov eax, 0x00ff00
    shl ecx, 4
    or eax, ecx
    jmp .paint
.c4:
    sub cl, 16*1
    not cl
    and cl, 15
    shl ecx, 12
    mov eax, 0x0000ff
    or eax, ecx
    jmp .paint
.c5:
    mov eax, 0x0000ff
    shl ecx, 20
    or eax, ecx
    jmp .paint
.c6:
    sub cl, 16*1
    not cl
    and cl, 15
    shl ecx, 4
    mov eax, 0xff0000
    or eax, ecx
    jmp .paint
.paint:
    mov [fs:edi+2], al
    shr eax, 8
    mov [fs:edi+1], al
    shr eax, 8
    mov [fs:edi], al
    add edi, 3

    inc word [x]
    pop cx
    dec cx
    test cx, cx
    jnz pix

    inc word [y]
    pop cx
    dec cx
    test cx, cx
    jnz row

waitkey:
    mov ah, 0x01
    int 0x21

exit:
    xor ah, ah
    mov al, [old_vga_mode]
    int 0x10
    int 0x20


x_min: dq -2.0
x_siz: dq 3.0
y_min: dq -1.0
y_siz: dq 2.0

old_vga_mode: db 0
target_vbe_mode equ 0x011b
iter: dw 16*6-1
threshsq: dq 4.0

gdtr:
    dw gdt.end - gdt - 1
.offset:
    dd 0

gdt:
    ; entry 0
    dq 0
    ; entry 1
    dw 0xffff ; limit 0xfffff, 0:15
    dw 0x0000 ; base 0, 0:15
    db 0x00   ; base 0, 16:23
    db 0x92   ; present | data | rw
    db 0xcf   ; 32 bit, 4 KiB granularity, limit 0xfffff 16:19
    db 0x00   ; base 0, 24:31
.end:

vbe_info:
    .signature db "VBE2"
    .data: ; resb 512 - 4, just let this run off the end of the program

end equ vbe_info.data + 512 - 4

vbe_mode_info equ end + 0
vbe_mode_bytes_per_line equ vbe_mode_info + 16
vbe_mode_width          equ vbe_mode_info + 18
vbe_mode_height         equ vbe_mode_info + 20
vbe_mode_framebuffer    equ vbe_mode_info + 40

x: dw 0
y: dw 0
