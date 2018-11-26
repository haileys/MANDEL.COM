use16
org 0x100

    fninit

    mov al, 0x13
    int 0x10

    mov ax, 0xa000
    mov es, ax
L:
    xor di, di
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

    mov al, cl
    stosb

    inc word [x]
    pop cx
    loop pix

    inc word [y]
    pop cx
    loop row

    cli
    hlt


x_min: dq -2.0
x_inc: dq 0.009375 ; 3.0 / 320
y_min: dq -1.0
y_inc: dq 0.01 ; 2.0 / 200


iter: dw 31
threshsq: dq 4.0

x: dw 0
y: dw 0
