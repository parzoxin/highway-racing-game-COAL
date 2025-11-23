[org 0x0100]

jmp start

; ============ DATA SECTION ============
oldkb: dd 0
oldtimer: dd 0
tickcount: dw 0
gameover: db 0
score: dw 0
carx: dw 151
cary: dw 175
carlane: db 1
lanepositions: dw 79, 151, 223

; Landscape scroll offset
scrolloffset: dw 0

; Enemy cars structure: 4 bytes each [lane, ypos_low, ypos_high, active]
numcars: db 0
enemycars: times 20 db 0  ; 5 cars * 4 bytes each
spawndelay: dw 0

; Bonus objects
bonusactive: db 0
bonuslane: db 0
bonusy: dw 0

rand_seed: dw 0

; ============ CONFIGURABLE SETTINGS ============
enemy_speed: dw 3
bonus_speed: dw 2
enemy_spawn_delay: dw 20
bonus_spawn_chance: dw 5

; ============ RANDOM NUMBER GENERATOR ============
get_random:
    push bx
    push cx
    push dx
    mov ax, [rand_seed]
    mov cx, 25173
    mul cx
    add ax, 13849
    mov [rand_seed], ax
    pop dx
    pop cx
    pop bx
    ret

; ============ CLEAR AND DRAW FULL SCREEN ============
redraw_screen:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov ax, 0xA000
    mov es, ax
    
    ; Draw entire screen fresh each frame
    mov dx, 0
row_loop:
    ; Left green belt (0-49)
    mov cx, 0
    mov di, cx
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    pop dx
    add di, ax
    mov al, 2
    mov bx, 50
fill_left:
    mov [es:di], al
    inc di
    dec bx
    jnz fill_left
    
    ; Road (50-269)
    mov al, 8
    mov bx, 220
fill_road:
    mov [es:di], al
    inc di
    dec bx
    jnz fill_road
    
    ; Right green belt (270-319)
    mov al, 2
    mov bx, 50
fill_right:
    mov [es:di], al
    inc di
    dec bx
    jnz fill_right
    
    inc dx
    cmp dx, 200
    jb row_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW LANE DIVIDERS ============
draw_lanes:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov ax, 0xA000
    mov es, ax
    
    mov si, [scrolloffset]
    
    ; Lane divider 1 (x=123)
    mov dx, 0
lane1_loop:
    mov ax, dx
    add ax, si
    and ax, 31
    cmp ax, 15
    jg lane1_skip
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 123
    mov di, ax
    mov al, 15
    mov [es:di], al
    pop dx
    
lane1_skip:
    inc dx
    cmp dx, 200
    jb lane1_loop
    
    ; Lane divider 2 (x=195)
    mov dx, 0
lane2_loop:
    mov ax, dx
    add ax, si
    and ax, 31
    cmp ax, 15
    jg lane2_skip
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 195
    mov di, ax
    mov al, 15
    mov [es:di], al
    pop dx
    
lane2_skip:
    inc dx
    cmp dx, 200
    jb lane2_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW TREES ON SIDES ============
draw_trees:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov ax, 0xA000
    mov es, ax
    
    mov si, [scrolloffset]
    
    ; Left side trees - more detailed
    mov bx, 0
left_tree_loop:
    mov ax, bx
    add ax, si
    xor dx, dx
    mov cx, 80
    div cx
    
    cmp dx, 60
    jge skip_left_tree
    
    ; Draw tree trunk at x=25 (brown)
    push bx
    mov ax, bx
    mov cx, 320
    mul cx
    add ax, 25
    mov di, ax
    mov al, 6
    mov cx, 5
trunk_left:
    mov [es:di], al
    inc di
    loop trunk_left
    
    ; Draw tree top (green) - pyramid shape
    mov ax, bx
    sub ax, 12
    cmp ax, 0
    jl no_tree_top
    mov cx, 320
    mul cx
    add ax, 20
    mov di, ax
    
    ; Tree top layers
    mov al, 10
    mov cx, 3
tree_layer_loop:
    push cx
    push di
    mov cx, 15
tree_top_row:
    mov [es:di], al
    inc di
    loop tree_top_row
    pop di
    add di, 320
    inc di
    pop cx
    loop tree_layer_loop
    
no_tree_top:
    pop bx
    
skip_left_tree:
    inc bx
    cmp bx, 200
    jb left_tree_loop
    
    ; Right side trees
    mov bx, 0
right_tree_loop:
    mov ax, bx
    add ax, si
    add ax, 40
    xor dx, dx
    mov cx, 80
    div cx
    
    cmp dx, 60
    jge skip_right_tree
    
    ; Draw tree trunk at x=290 (brown)
    push bx
    mov ax, bx
    mov cx, 320
    mul cx
    add ax, 290
    mov di, ax
    mov al, 6
    mov cx, 5
trunk_right:
    mov [es:di], al
    inc di
    loop trunk_right
    
    ; Draw tree top (green) - pyramid shape
    mov ax, bx
    sub ax, 12
    cmp ax, 0
    jl no_tree_top_right
    mov cx, 320
    mul cx
    add ax, 285
    mov di, ax
    
    ; Tree top layers
    mov al, 10
    mov cx, 3
tree_layer_loop_right:
    push cx
    push di
    mov cx, 15
tree_top_row_right:
    mov [es:di], al
    inc di
    loop tree_top_row_right
    pop di
    add di, 320
    inc di
    pop cx
    loop tree_layer_loop_right
    
no_tree_top_right:
    pop bx
    
skip_right_tree:
    inc bx
    cmp bx, 200
    jb right_tree_loop
    
    ; Left bushes - more varied
    mov bx, 0
left_bush_loop:
    mov ax, bx
    add ax, si
    xor dx, dx
    mov cx, 40
    div cx
    
    cmp dx, 15
    jge skip_left_bush
    
    push bx
    mov ax, bx
    mov cx, 320
    mul cx
    add ax, 5
    mov di, ax
    mov al, 10
    
    ; Draw bush with some variation
    mov cx, 3
bush_layer_left:
    push cx
    push di
    mov cx, 20
bush_left:
    mov [es:di], al
    inc di
    loop bush_left
    pop di
    add di, 320
    sub di, 2
    pop cx
    loop bush_layer_left
    
    pop bx
    
skip_left_bush:
    inc bx
    cmp bx, 200
    jb left_bush_loop
    
    ; Right bushes - more varied
    mov bx, 0
right_bush_loop:
    mov ax, bx
    add ax, si
    add ax, 20
    xor dx, dx
    mov cx, 40
    div cx
    
    cmp dx, 15
    jge skip_right_bush
    
    push bx
    mov ax, bx
    mov cx, 320
    mul cx
    add ax, 295
    mov di, ax
    mov al, 10
    
    ; Draw bush with some variation
    mov cx, 3
bush_layer_right:
    push cx
    push di
    mov cx, 20
bush_right:
    mov [es:di], al
    inc di
    loop bush_right
    pop di
    add di, 320
    sub di, 2
    pop cx
    loop bush_layer_right
    
    pop bx
    
skip_right_bush:
    inc bx
    cmp bx, 200
    jb right_bush_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW PLAYER CAR ============
DrawCar:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov ax, 0xA000
    mov es, ax
    
    ; Main body (16x21) - RED
    mov dx, [cary]
    mov bx, dx
    add bx, 21
car_body_y:
    mov cx, [carx]
    push cx
    push dx
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, cx
    mov di, ax
    pop dx
    pop cx
    
    push bx
    mov bx, 16
car_body_x:
    mov byte [es:di], 4
    inc di
    dec bx
    jnz car_body_x
    pop bx
    
    inc dx
    cmp dx, bx
    jb car_body_y
    
    ; Wheels
    mov dx, [cary]
    add dx, 3
    mov bx, 7
lw1_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    sub cx, 2
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz lw1_loop
    
    mov dx, [cary]
    add dx, 3
    mov bx, 7
rw1_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    add cx, 16
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz rw1_loop
    
    mov dx, [cary]
    add dx, 14
    mov bx, 7
lw2_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    sub cx, 2
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz lw2_loop
    
    mov dx, [cary]
    add dx, 14
    mov bx, 7
rw2_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    add cx, 16
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz rw2_loop
    
    ; Window - CYAN
    mov dx, [cary]
    add dx, 7
    mov bx, 6
win_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    add cx, 4
    add ax, cx
    mov di, ax
    mov cx, 8
win_x:
    mov byte [es:di], 11
    inc di
    loop win_x
    pop dx
    inc dx
    dec bx
    jnz win_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW ENEMY CAR (BLUE or YELLOW) ============
draw_enemy_car:
    ; Input: AX=x, DX=y, BL=color (1=blue, 14=yellow)
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push es
    
    mov si, ax
    mov ax, 0xA000
    mov es, ax
    
    ; Get the color from BL and store it
    mov al, bl
    push ax
    
    push dx
    mov bx, dx
    add bx, 21
    
enemy_body_y:
    mov cx, si
    push cx
    push dx
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, cx
    mov di, ax
    pop dx
    pop cx
    
    push bx
    mov bx, 16
    mov al, [esp+4]  ; Get color from stack
enemy_body_x:
    mov [es:di], al
    inc di
    dec bx
    jnz enemy_body_x
    pop bx
    
    inc dx
    cmp dx, bx
    jb enemy_body_y
    
    pop dx
    pop ax  ; Remove color from stack
    
    ; Wheels
    push dx
    add dx, 3
    mov bx, 7
elw1:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    sub cx, 2
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz elw1
    pop dx
    
    push dx
    add dx, 3
    mov bx, 7
erw1:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    add cx, 16
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz erw1
    pop dx
    
    push dx
    add dx, 14
    mov bx, 7
elw2:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    sub cx, 2
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz elw2
    pop dx
    
    push dx
    add dx, 14
    mov bx, 7
erw2:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    add cx, 16
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    pop dx
    inc dx
    dec bx
    jnz erw2
    pop dx
    
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ SPAWN ENEMY CAR ============
spawn_enemy:
    push ax
    push bx
    push si
    push cx
    
    mov ax, [spawndelay]
    cmp ax, 0
    je can_spawn
    dec word [spawndelay]
    jmp skipspawn
    
can_spawn:
    call get_random
    and al, 0x1F
    cmp al, 5
    jg skipspawn
    
    mov al, [numcars]
    cmp al, 3
    jge skipspawn
    
    mov si, enemycars
    mov cx, 5
    
findempty:
    cmp byte [si+3], 0
    je foundempty
    add si, 4
    loop findempty
    jmp skipspawn
    
foundempty:
    call get_random
    xor ah, ah
    mov bl, 3
    div bl
    mov [si], ah
    
    mov word [si+1], -30
    mov byte [si+3], 1
    
    inc byte [numcars]
    
    mov ax, [enemy_spawn_delay]
    mov [spawndelay], ax
    
skipspawn:
    pop cx
    pop si
    pop bx
    pop ax
    ret

; ============ SPAWN BONUS ============
spawn_bonus:
    push ax
    push bx
    
    cmp byte [bonusactive], 1
    je skipbonus
    
    call get_random
    and ax, 0x0FF
    mov bx, [bonus_spawn_chance]
    cmp ax, bx
    jg skipbonus
    
    call get_random
    xor ah, ah
    mov bl, 3
    div bl
    mov [bonuslane], ah
    mov word [bonusy], -20
    mov byte [bonusactive], 1
    
skipbonus:
    pop bx
    pop ax
    ret

; ============ DRAW ENEMIES ============
draw_enemies:
    push ax
    push bx
    push cx
    push dx
    push si
    push bp
    
    mov si, enemycars
    mov cx, 5
    
drawnext:
    cmp byte [si+3], 0
    je skipthis
    
    movzx bx, byte [si]
    shl bx, 1
    mov ax, [lanepositions+bx]
    sub ax, 8
    
    mov dx, [si+1]
    
    cmp dx, -20
    jl skipthis
    cmp dx, 200
    jge skipthis
    
    ; Check if overlapping with bonus - skip drawing if so
    cmp byte [bonusactive], 0
    je no_bonus_overlap
    
    mov bp, [bonusy]
    sub bp, 25
    cmp dx, bp
    jl no_bonus_overlap
    
    mov bp, [bonusy]
    add bp, 25
    cmp dx, bp
    jg no_bonus_overlap
    
    ; Check if same lane as bonus
    mov al, [si]
    cmp al, [bonuslane]
    je skipthis  ; Skip drawing this enemy if overlapping with bonus
    
no_bonus_overlap:
    push si
    push cx
    
    ; Determine color: alternate blue and yellow
    mov cx, si
    sub cx, enemycars
    shr cx, 2
    and cx, 1
    jz use_blue
    mov bl, 14  ; Yellow
    jmp draw_it
use_blue:
    mov bl, 1  ; Blue
draw_it:
    call draw_enemy_car
    
    pop cx
    pop si
    
skipthis:
    add si, 4
    loop drawnext
    
    pop bp
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW BONUS ============
draw_bonus:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    cmp byte [bonusactive], 0
    je skipbonus2
    
    mov ax, 0xA000
    mov es, ax
    
    movzx bx, byte [bonuslane]
    shl bx, 1
    mov cx, [lanepositions+bx]
    sub cx, 4
    
    mov dx, [bonusy]
    
    cmp dx, -20
    jl skipbonus2
    cmp dx, 200
    jge skipbonus2
    
    ; Draw bonus as a yellow square
    push dx
    mov bx, 8
bonus_row:
    push cx
    push dx
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, cx
    mov di, ax
    pop dx
    pop cx
    
    push bx
    mov bx, 8
bonus_pix:
    mov byte [es:di], 14
    inc di
    dec bx
    jnz bonus_pix
    pop bx
    
    inc dx
    dec bx
    jnz bonus_row
    pop dx
    
skipbonus2:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ UPDATE ENEMIES ============
update_enemies:
    push si
    push cx
    push ax
    
    mov si, enemycars
    mov cx, 5
    
updatenext:
    cmp byte [si+3], 0
    je skipupdate
    
    mov ax, [enemy_speed]
    add [si+1], ax
    
    mov ax, [si+1]
    cmp ax, 220
    jl skipupdate
    
    mov byte [si+3], 0
    dec byte [numcars]
    
skipupdate:
    add si, 4
    loop updatenext
    
    pop ax
    pop cx
    pop si
    ret

; ============ UPDATE BONUS ============
update_bonus:
    push ax
    
    cmp byte [bonusactive], 0
    je skipupdate_bonus
    
    mov ax, [bonus_speed]
    add [bonusy], ax
    
    mov ax, [bonusy]
    cmp ax, 220
    jl skipupdate_bonus
    
    mov byte [bonusactive], 0
    
skipupdate_bonus:
    pop ax
    ret

; ============ CHECK COLLISION ============
check_collision:
    push si
    push ax
    push bx
    push cx
    
    mov si, enemycars
    mov cx, 5
    
checknext:
    cmp byte [si+3], 0
    je skipcheck
    
    mov ax, [si+1]
    add ax, 10
    
    cmp ax, 165
    jl skipcheck
    cmp ax, 190
    jg skipcheck
    
    mov al, [carlane]
    cmp al, [si]
    jne skipcheck
    
    mov byte [gameover], 1
    
skipcheck:
    add si, 4
    loop checknext
    
    cmp byte [bonusactive], 0
    je skipbonus_check
    
    mov ax, [bonusy]
    add ax, 4
    
    cmp ax, 165
    jl skipbonus_check
    cmp ax, 190
    jg skipbonus_check
    
    mov al, [carlane]
    cmp al, [bonuslane]
    jne skipbonus_check
    
    add word [score], 10
    mov byte [bonusactive], 0
    
skipbonus_check:
    pop cx
    pop bx
    pop ax
    pop si
    ret

; ============ IMPROVED SHOW SCORE (from second code) ============
show_score:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push es
    
    mov ax, 0xA000
    mov es, ax
    
    ; Clear score area with black
    mov dx, 5
    mov cx, 15
clear_score_y:
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 250
    mov di, ax
    pop dx
    
    push cx
    mov cx, 60
    mov al, 0
clear_score_x:
    mov [es:di], al
    inc di
    loop clear_score_x
    pop cx
    
    inc dx
    loop clear_score_y
    
    ; Display score number (right aligned)
    mov ax, [score]
    mov bx, 10
    mov cx, 0
    
    ; Extract digits
get_digits:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne get_digits
    
    ; Make sure we have at least 1 digit
    cmp cx, 0
    jne has_digits
    push 0
    inc cx
    
has_digits:
    ; Position for rightmost digit
    mov di, 300
    sub di, cx
    sub di, cx
    sub di, cx
    sub di, cx
    sub di, cx  ; 5 pixels per digit
    
draw_score_digits:
    pop dx
    push cx
    push di
    
    ; Draw digit
    mov ax, dx
    call draw_digit
    
    pop di
    add di, 6
    pop cx
    loop draw_score_digits
    
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw a single digit (0-9) using actual digit patterns
draw_digit:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov bx, ax  ; Save digit value
    mov dx, 10  ; Y position
    
    ; Calculate digit pattern offset
    mov ax, bx
    mov cx, 25  ; 5 rows * 5 pixels per row
    mul cx
    mov si, ax
    add si, digit_patterns
    
    ; Draw 5x5 digit
    mov cx, 5   ; 5 rows
draw_digit_row:
    push cx
    push di
    push dx
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, di
    mov di, ax
    
    mov cx, 5   ; 5 columns
draw_digit_col:
    lodsb
    cmp al, 0
    je skip_pixel
    mov byte [es:di], 15  ; White
skip_pixel:
    inc di
    loop draw_digit_col
    
    pop dx
    inc dx
    pop di
    pop cx
    loop draw_digit_row
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Digit patterns (5x5 for each digit 0-9)
digit_patterns:
    ; 0
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    ; 1
    db 0,0,1,0,0
    db 0,1,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,1,1,1,0
    ; 2
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 1,1,1,1,1
    db 1,0,0,0,0
    db 1,1,1,1,1
    ; 3
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 1,1,1,1,1
    ; 4
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 0,0,0,0,1
    ; 5
    db 1,1,1,1,1
    db 1,0,0,0,0
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 1,1,1,1,1
    ; 6
    db 1,1,1,1,1
    db 1,0,0,0,0
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    ; 7
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    ; 8
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    ; 9
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 1,1,1,1,1

; ============ KEYBOARD ISR ============
kbisr:
    push ax
    push bx
    push ds
    
    push cs
    pop ds
    
    in al, 0x60
    
    cmp al, 0x4B
    je leftpressed
    
    cmp al, 0x4D
    je rightpressed
    
    jmp kbdone
    
leftpressed:
    cmp byte [carlane], 0
    je kbdone
    dec byte [carlane]
    movzx bx, byte [carlane]
    shl bx, 1
    mov ax, [lanepositions+bx]
    mov [carx], ax
    jmp kbdone
    
rightpressed:
    cmp byte [carlane], 2
    je kbdone
    inc byte [carlane]
    movzx bx, byte [carlane]
    shl bx, 1
    mov ax, [lanepositions+bx]
    mov [carx], ax
    
kbdone:
    mov al, 0x20
    out 0x20, al
    
    pop ds
    pop bx
    pop ax
    iret

; ============ TIMER ISR ============
timer:
    push ax
    push ds
    
    push cs
    pop ds
    
    inc word [tickcount]
    cmp word [tickcount], 2
    jl timerdone
    
    mov word [tickcount], 0
    
    cmp byte [gameover], 1
    je timerdone
    
    inc word [scrolloffset]
    
    call redraw_screen
    call draw_lanes
    call draw_trees
    call spawn_enemy
    call spawn_bonus
    call update_enemies
    call update_bonus
    call draw_enemies
    call draw_bonus
    call DrawCar
    call check_collision
    call show_score
    
    inc word [score]
    
timerdone:
    mov al, 0x20
    out 0x20, al
    
    pop ds
    pop ax
    iret

; ============ MAIN PROGRAM ============
start:
    xor ax, ax
    int 0x1A
    mov [rand_seed], dx
    
    xor ax, ax
    mov es, ax
    
    mov ax, [es:9*4]
    mov [oldkb], ax
    mov ax, [es:9*4+2]
    mov [oldkb+2], ax
    
    cli
    mov ax, kbisr
    mov [es:9*4], ax
    mov [es:9*4+2], cs
    sti
    
    mov ax, [es:8*4]
    mov [oldtimer], ax
    mov ax, [es:8*4+2]
    mov [oldtimer+2], ax
    
    cli
    mov ax, timer
    mov [es:8*4], ax
    mov [es:8*4+2], cs
    sti
    
    mov ax, 0x0013
    int 0x10
    
gameloop:
    cmp byte [gameover], 1
    je endgame
    
    hlt
    jmp gameloop
    
endgame:
    xor ax, ax
    mov es, ax
    
    cli
    mov ax, [oldkb]
    mov [es:9*4], ax
    mov ax, [oldkb+2]
    mov [es:9*4+2], ax
    
    mov ax, [oldtimer]
    mov [es:8*4], ax
    mov ax, [oldtimer+2]
    mov [es:8*4+2], ax
    sti
    
    mov ax, 0x0003
    int 0x10
    
    mov ax, 0x4c00
    int 0x21