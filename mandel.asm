use16
org 0x100

    fninit

    ; get video mode
    mov ah, 0x0f
    int 0x10
    mov [vga_mode], al

    ; switch to mode 13h
    mov ax, 0x13
    int 0x10

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

    ; load 32 bit descriptor into es
    mov bx, 0x08
    mov es, bx

    ; leave protected mode, now in unreal mode
    and al, ~1
    mov cr0, eax
L:
    mov edi, 0xa0000
    mov word [y], 0
    mov cx, 200
row:
    push cx

    mov word [x], 0
    mov cx, 320
pix:
    push cx

    ; calculate imaginary component
    fld qword [y_inc]
    fimul word [y]
    fld qword [y_min]
    faddp

    ; calculate real component
    fld qword [x_inc]
    fimul word [x]
    fld qword [x_min]
    faddp
    ; C is st0 + st1*i

    fldz ; init z0
    fldz

    mov cx, [iter]
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

    mov [es:edi], cl
    inc edi

    inc word [x]
    pop cx
    loop pix

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
    mov al, [vga_mode]
    int 0x10
    int 0x20


x_min: dq -2.0
x_inc: dq 0.009375 ; 3.0 / 320
y_min: dq -1.0
y_inc: dq 0.01 ; 2.0 / 200

vga_mode: db 0
iter: dw 31
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


x: dw 0
y: dw 0
