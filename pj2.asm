;almost perfect
;Enhanced Racing Game with improved graphics and smooth scrolling
[org 0x0100]

jmp start

; ============ DATA SECTION ============
oldkb: dd 0
oldtimer: dd 0
tickcount: dw 0
gameover: db 0
score: dw 0
carx: dw 149
cary: dw 175
carlane: db 1
lanepositions: dw 77, 149, 221
carpositions: dw 77, 149, 221

scrolloffset: dw 0
numcars: db 0
enemycars: times 20 db 0
spawndelay: dw 0
bonusactive: db 0
bonuslane: db 0
bonusy: dw 0
rand_seed: dw 0

; ============ NEW FEATURES DATA ============
game_state: db 0  ; 0=intro, 1=playing, 2=paused, 3=gameover
pause_flag: db 0  ; Flag to indicate ESC was pressed

; Text strings
title_str: db 'RACING GAME', 0
names_str: db 'Abdul Ahad Khan & Ahmad Babar', 0
roll_str: db '24L-0954 & 24L-0644', 0
semester_str: db 'Fall 2025', 0
press_key_str: db 'Press any key to start...', 0
pause_confirm_str: db 'Exit game? (Y/N)', 0
game_over_str: db 'GAME OVER', 0
final_score_str: db 'Final Score: ', 0
replay_str: db 'Press R to Replay or E to Exit', 0
controls_str: db 'Controls: Arrow Keys to Move, ESC to Pause', 0

; ============ CONFIGURABLE SETTINGS ============
enemy_speed: dw 5 ; Reduced for smoother movement
bonus_speed: dw 2
enemy_spawn_delay: dw 40
bonus_spawn_chance: dw 5

; ============ TEXT MODE FUNCTIONS ============
set_text_mode:
    mov ax, 0x0003
    int 0x10
    ret

set_graphics_mode:
    mov ax, 0x0013
    int 0x10
    ret

clear_screen_text:
    push ax
    push cx
    push di
    push es
    mov ax, 0xB800
    mov es, ax
    mov di, 0
    mov cx, 2000
    mov ax, 0x0720
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    ret

print_string_colored: ; si=string, di=screen_position, ah=color
    push ax
    push si
    push di
.loop:
    mov al, [si]
    cmp al, 0
    je .done
    mov [es:di], ax
    inc si
    add di, 2
    jmp .loop
.done:
    pop di
    pop si
    pop ax
    ret

draw_box:  ; Draw a decorative box around text
    push ax
    push bx
    push cx
    push di
    
    ; Top border
    mov di, 160*6 + 20*2
    mov cx, 40
    mov ax, 0x0FCD  ; White horizontal line
.top:
    mov [es:di], ax
    add di, 2
    loop .top
    
    ; Bottom border
    mov di, 160*16 + 20*2
    mov cx, 40
.bottom:
    mov [es:di], ax
    add di, 2
    loop .bottom
    
    ; Side borders
    mov bx, 7
.sides:
    mov di, bx
    shl di, 7
    add di, bx
    add di, bx
    shl di, 1
    add di, 20*2
    mov ax, 0x0FBA  ; White vertical line
    mov [es:di], ax
    add di, 80
    mov [es:di], ax
    inc bx
    cmp bx, 16
    jl .sides
    
    pop di
    pop cx
    pop bx
    pop ax
    ret

; ============ INTRODUCTION SCREEN ============
show_intro_screen:
    call set_text_mode
    call clear_screen_text
    
    mov ax, 0xB800
    mov es, ax
    
    ; Draw decorative box
    call draw_box
    
    ; Game title (bright cyan)
    mov si, title_str
    mov di, 160*8 + 34*2
    mov ah, 0x0B
    call print_string_colored
    
    ; Names (yellow)
    mov si, names_str
    mov di, 160*10 + 25*2
    mov ah, 0x0E
    call print_string_colored
    
    ; Roll numbers (light green)
    mov si, roll_str
    mov di, 160*11 + 29*2
    mov ah, 0x0A
    call print_string_colored
    
    ; Semester (light blue)
    mov si, semester_str
    mov di, 160*13 + 35*2
    mov ah, 0x09
    call print_string_colored
    
    ; Controls (white)
    mov si, controls_str
    mov di, 160*20 + 19*2
    mov ah, 0x0F
    call print_string_colored
    
    ; Press any key (blinking white)
    mov si, press_key_str
    mov di, 160*22 + 27*2
    mov ah, 0x8F
    call print_string_colored
    
    ; Wait for key press
    mov ah, 0
    int 0x16
    
    ret

; ============ SIMPLE PAUSE CONFIRMATION ============
show_pause_confirm:
    push ax
    push es
    xor ax, ax
    mov es, ax
    
    cli
    mov ax, [oldkb]
    mov [es:9*4], ax
    mov ax, [oldkb+2]
    mov [es:9*4+2], ax
    sti
    
    pop es
    pop ax
    
    call set_text_mode
    call clear_screen_text
    
    mov ax, 0xB800
    mov es, ax
    
    ; Display confirmation prompt (bright white)
    mov si, pause_confirm_str
    mov di, 160*12 + 32
    mov ah, 0x0F
    call print_string_colored
    
.wait_input:
    mov ah, 0
    int 0x16
    
    cmp al, 'Y'
    je .exit_game
    cmp al, 'y'
    je .exit_game
    cmp al, 'N'
    je .resume_game
    cmp al, 'n'
    je .resume_game
    
    jmp .wait_input

.exit_game:
    mov byte [gameover], 1
    mov byte [game_state], 3
    ret

.resume_game:
    push ax
    push es
    xor ax, ax
    mov es, ax
    
    cli
    mov word [es:9*4], kbisr
    mov [es:9*4+2], cs
    sti
    
    pop es
    pop ax
    
    call set_graphics_mode
    mov byte [game_state], 1
    ret

; ============ GAME OVER SCREEN ============
show_game_over_screen:
    push ax
    push es
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
    
    pop es
    pop ax
    
    mov cx, 0xFFFF
.delay:
    loop .delay
    
    call set_text_mode
    call clear_screen_text
    
    mov ax, 0xB800
    mov es, ax
    
    ; Draw box
    call draw_box
    
    ; Game over text (bright red)
    mov si, game_over_str
    mov di, 160*9 + 35*2
    mov ah, 0x0C
    call print_string_colored
    
    ; Final score text (bright yellow)
    mov si, final_score_str
    mov di, 160*12 + 33*2
    mov ah, 0x0E
    call print_string_colored
    
    ; Display score (bright cyan)
    mov ax, [score]
    mov di, 160*12 + 47*2
    mov bl, 0x0B
    call display_number
    
    ; Replay or exit instruction (bright white)
    mov si, replay_str
    mov di, 160*15 + 24*2
    mov ah, 0x0F
    call print_string_colored
    
.clear_buffer:
    mov ah, 1
    int 0x16
    jz .buffer_empty
    mov ah, 0
    int 0x16
    jmp .clear_buffer
    
.buffer_empty:
.wait_choice:
    mov ah, 0
    int 0x16
    
    cmp al, 'R'
    je .replay_game
    cmp al, 'r'
    je .replay_game
    cmp al, 'E'
    je .exit_game
    cmp al, 'e'
    je .exit_game
    
    jmp .wait_choice

.replay_game:
    mov byte [game_state], 0
    ret

.exit_game:
    mov byte [game_state], 3
	jmp clear_screen_text
    ret

display_number: ; ax=number, di=screen_position, bl=color
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov bh, bl  ; Save color
    mov bx, 10
    mov cx, 0
    
.convert_loop:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    test ax, ax
    jnz .convert_loop
    
.display_loop:
    pop ax
    mov ah, bh  ; Restore color
    mov [es:di], ax
    add di, 2
    loop .display_loop
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ SIMPLIFIED KEYBOARD ISR ============
kbisr:
    push ax
    push ds
    
    push cs
    pop ds
    
    in al, 0x60
    
    cmp al, 0x01
    jne .not_esc
    
    test al, 0x80
    jnz .not_esc
    
    mov byte [pause_flag], 1
    jmp .done
    
.not_esc:
    cmp byte [game_state], 1
    jne .done
    
    test al, 0x80
    jnz .done
    
    cmp al, 0x4B
    je .leftpressed
    
    cmp al, 0x4D
    je .rightpressed
    
    jmp .done

.leftpressed:
    cmp byte [carlane], 0
    je .done
    dec byte [carlane]
    movzx bx, byte [carlane]
    shl bx, 1
    mov ax, [lanepositions+bx]
    mov [carx], ax
    jmp .done
    
.rightpressed:
    cmp byte [carlane], 2
    je .done
    inc byte [carlane]
    movzx bx, byte [carlane]
    shl bx, 1
    mov ax, [lanepositions+bx]
    mov [carx], ax

.done:
    mov al, 0x20
    out 0x20, al
    
    pop ds
    pop ax
    iret

; ============ TIMER ISR ============
timer:
    push ax
    push ds
    
    push cs
    pop ds
    
    cmp byte [game_state], 1
    jne .done
    
    inc word [tickcount]
    cmp word [tickcount], 2
    jl .timerdone
    
    mov word [tickcount], 0
    
    cmp byte [gameover], 1
    je .game_over
    
    add word [scrolloffset], 2
    
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
    jmp .timerdone

.game_over:
    mov byte [game_state], 3

.timerdone:
    mov al, 0x20
    out 0x20, al

.done:
    pop ds
    pop ax
    iret

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

; ============ RESET GAME STATE ============
reset_game_state:
    push ax
    push bx
    push cx
    push si
    
    mov word [tickcount], 0
    mov byte [gameover], 0
    mov word [score], 0
    mov word [carx], 149
    mov word [cary], 175
    mov byte [carlane], 1
    
    mov word [scrolloffset], 0
    mov byte [numcars], 0
    mov word [spawndelay], 0
    mov byte [bonusactive], 0
    mov byte [bonuslane], 0
    mov word [bonusy], 0
    mov byte [pause_flag], 0
    
    mov si, enemycars
    mov cx, 20
    xor al, al
.clear_enemies:
    mov [si], al
    inc si
    loop .clear_enemies
    
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ============ MAIN PROGRAM ============
start:
game_restart:
    call reset_game_state
    call show_intro_screen
    
    xor ax, ax
    int 0x1A
    mov [rand_seed], dx
    
    call set_graphics_mode
    
    xor ax, ax
    mov es, ax
    
    mov ax, [es:9*4]
    mov [oldkb], ax
    mov ax, [es:9*4+2]
    mov [oldkb+2], ax
    
    mov ax, [es:8*4]
    mov [oldtimer], ax
    mov ax, [es:8*4+2]
    mov [oldtimer+2], ax
    
    cli
    mov word [es:9*4], kbisr
    mov [es:9*4+2], cs
    mov word [es:8*4], timer
    mov [es:8*4+2], cs
    sti
    
    mov byte [game_state], 1

gameloop:
    cmp byte [game_state], 3
    je endgame
    
    cmp byte [pause_flag], 1
    je handle_pause
    
    hlt
    jmp gameloop

handle_pause:
    mov byte [pause_flag], 0
    call show_pause_confirm
    jmp gameloop
    
endgame:
    call show_game_over_screen
    
    cmp byte [game_state], 0
    je game_restart
    
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
    
    mov ax, 0x4c00
    int 0x21

; ============ REDRAW SCREEN WITH DOUBLE BUFFERING CONCEPT ============
redraw_screen:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov ax, 0xA000
    mov es, ax
    
    ; Draw entire screen
    mov dx, 0
.row_loop:
    mov cx, 0
    mov di, cx
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    pop dx
    add di, ax
    
    ; Left green belt (0-49)
    mov al, 2
    mov bx, 50
.fill_left:
    mov [es:di], al
    inc di
    dec bx
    jnz .fill_left
    
    ; Road (50-269)
    mov al, 8
    mov bx, 220
.fill_road:
    mov [es:di], al
    inc di
    dec bx
    jnz .fill_road
    
    ; Right green belt (270-319)
    mov al, 2
    mov bx, 50
.fill_right:
    mov [es:di], al
    inc di
    dec bx
    jnz .fill_right
    
    inc dx
    cmp dx, 200
    jb .row_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW SMOOTH LANE DIVIDERS ============
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
    neg si

    ; Lane divider 1 (x=123)
    mov dx, 0
.lane1_loop:
    mov ax, dx
    add ax, si
    and ax, 31
    cmp ax, 15
    jg .lane1_skip
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 123
    mov di, ax
    mov al, 15
    mov [es:di], al
    inc di
    mov [es:di], al  ; Make lines thicker
    pop dx
    
.lane1_skip:
    inc dx
    cmp dx, 200
    jb .lane1_loop
    
    ; Lane divider 2 (x=195)
    mov dx, 0
.lane2_loop:
    mov ax, dx
    add ax, si
    and ax, 31
    cmp ax, 15
    jg .lane2_skip
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 195
    mov di, ax
    mov al, 15
    mov [es:di], al
    inc di
    mov [es:di], al  ; Make lines thicker
    pop dx
    
.lane2_skip:
    inc dx
    cmp dx, 200
    jb .lane2_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW ENHANCED TREES AND FOLIAGE ============
draw_trees:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    push bp
    
    mov ax, 0xA000
    mov es, ax
    
    mov si, [scrolloffset]
    neg si
    
    ; Left side - trees and bushes
    mov bp, 0  ; Y position counter
.left_side_loop:
    mov ax, bp
    add ax, si
    xor dx, dx
    mov cx, 50  ; Tree spacing
    div cx
    
    ; Check if we should draw a tree
    cmp dx, 35
    jge near .try_left_bush
    
    ; Calculate base Y position for this tree
    mov bx, bp
    
    ; Draw complete tree (crown then trunk)
    ; Tree crown first (top part)
    mov ax, bx
    cmp ax, 15
    jl near .try_left_bush  ; Don't draw if too close to top
    
    ; Crown layer 1 (topmost, smallest)
    sub ax, 15
    push bx
    mov bx, 320
    mul bx
    add ax, 18
    mov di, ax
    mov al, 2  ; Dark green
    mov cx, 14
.left_crown1:
    mov [es:di], al
    inc di
    loop .left_crown1
    pop bx
    
    ; Crown layer 2
    mov ax, bx
    sub ax, 12
    cmp ax, 0
    jl near .try_left_bush
    push bx
    mov bx, 320
    mul bx
    add ax, 16
    mov di, ax
    mov al, 10  ; Bright green
    mov cx, 18
.left_crown2:
    mov [es:di], al
    inc di
    loop .left_crown2
    pop bx
    
    ; Crown layer 3
    mov ax, bx
    sub ax, 9
    cmp ax, 0
    jl near .try_left_bush
    push bx
    mov bx, 320
    mul bx
    add ax, 15
    mov di, ax
    mov al, 2  ; Dark green
    mov cx, 20
.left_crown3:
    mov [es:di], al
    inc di
    loop .left_crown3
    pop bx
    
    ; Tree trunk
    mov cx, 8  ; Trunk height
.left_trunk_loop:
    mov ax, bx
    cmp ax, 200
    jge near .try_left_bush
    push bx
    push cx
    mov bx, 320
    mul bx
    add ax, 22
    mov di, ax
    mov al, 6  ; Brown
    mov cx, 6  ; Trunk width
.left_trunk_row:
    mov [es:di], al
    inc di
    loop .left_trunk_row
    pop cx
    pop bx
    inc bx
    loop .left_trunk_loop
    jmp near .next_left_pos
    
.try_left_bush:
    ; Try to draw a bush
    mov ax, bp
    add ax, si
    add ax, 25  ; Offset from trees
    xor dx, dx
    mov cx, 40
    div cx
    
    cmp dx, 25
    jge near .next_left_pos
    
    ; Draw small bush
    mov bx, bp
    mov cx, 6  ; Bush height
.left_bush_loop:
    mov ax, bx
    cmp ax, 200
    jge near .next_left_pos
    push bx
    push cx
    mov bx, 320
    mul bx
    add ax, 8
    mov di, ax
    mov al, 10  ; Bright green
    mov cx, 12  ; Bush width
.left_bush_row:
    mov [es:di], al
    inc di
    loop .left_bush_row
    pop cx
    pop bx
    inc bx
    loop .left_bush_loop
    
.next_left_pos:
    inc bp
    cmp bp, 200
    jb near .left_side_loop
    
    ; Right side - trees and bushes
    mov bp, 0
.right_side_loop:
    mov ax, bp
    add ax, si
    add ax, 25  ; Different offset for variety
    xor dx, dx
    mov cx, 50
    div cx
    
    ; Check if we should draw a tree
    cmp dx, 35
    jge near .try_right_bush
    
    mov bx, bp
    
    ; Draw complete tree
    ; Crown layer 1
    mov ax, bx
    cmp ax, 15
    jl near .try_right_bush
    
    sub ax, 15
    push bx
    mov bx, 320
    mul bx
    add ax, 288
    mov di, ax
    mov al, 2
    mov cx, 14
.right_crown1:
    mov [es:di], al
    inc di
    loop .right_crown1
    pop bx
    
    ; Crown layer 2
    mov ax, bx
    sub ax, 12
    cmp ax, 0
    jl near .try_right_bush
    push bx
    mov bx, 320
    mul bx
    add ax, 286
    mov di, ax
    mov al, 10
    mov cx, 18
.right_crown2:
    mov [es:di], al
    inc di
    loop .right_crown2
    pop bx
    
    ; Crown layer 3
    mov ax, bx
    sub ax, 9
    cmp ax, 0
    jl near .try_right_bush
    push bx
    mov bx, 320
    mul bx
    add ax, 285
    mov di, ax
    mov al, 2
    mov cx, 20
.right_crown3:
    mov [es:di], al
    inc di
    loop .right_crown3
    pop bx
    
    ; Trunk
    mov cx, 8
.right_trunk_loop:
    mov ax, bx
    cmp ax, 200
    jge near .try_right_bush
    push bx
    push cx
    mov bx, 320
    mul bx
    add ax, 292
    mov di, ax
    mov al, 6
    mov cx, 6
.right_trunk_row:
    mov [es:di], al
    inc di
    loop .right_trunk_row
    pop cx
    pop bx
    inc bx
    loop .right_trunk_loop
    jmp near .next_right_pos
    
.try_right_bush:
    ; Try to draw a bush
    mov ax, bp
    add ax, si
    xor dx, dx
    mov cx, 40
    div cx
    
    cmp dx, 25
    jge near .next_right_pos
    
    ; Draw small bush
    mov bx, bp
    mov cx, 6
.right_bush_loop:
    mov ax, bx
    cmp ax, 200
    jge near .next_right_pos
    push bx
    push cx
    mov bx, 320
    mul bx
    add ax, 300
    mov di, ax
    mov al, 10
    mov cx, 12
.right_bush_row:
    mov [es:di], al
    inc di
    loop .right_bush_row
    pop cx
    pop bx
    inc bx
    loop .right_bush_loop
    
.next_right_pos:
    inc bp
    cmp bp, 200
    jb near .right_side_loop
    
    pop bp
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
    
    ; Main body (20x25) - RED
    mov dx, [cary]
    mov bx, dx
    add bx, 25
.car_body_y:
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
    mov bx, 20
.car_body_x:
    mov byte [es:di], 4
    inc di
    dec bx
    jnz .car_body_x
    pop bx
    
    inc dx
    cmp dx, bx
    jb .car_body_y
    
    ; Wheels (black)
    mov dx, [cary]
    add dx, 3
    mov bx, 8
.lw1_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    sub cx, 3
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .lw1_loop
    
    mov dx, [cary]
    add dx, 3
    mov bx, 8
.rw1_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    add cx, 20
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .rw1_loop
    
    mov dx, [cary]
    add dx, 17
    mov bx, 8
.lw2_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    sub cx, 3
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .lw2_loop
    
    mov dx, [cary]
    add dx, 17
    mov bx, 8
.rw2_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    add cx, 20
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .rw2_loop
    
    ; Window - CYAN
    mov dx, [cary]
    add dx, 8
    mov bx, 9
.win_loop:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, [carx]
    add cx, 5
    add ax, cx
    mov di, ax
    mov cx, 10
.win_x:
    mov byte [es:di], 11
    inc di
    loop .win_x
    pop dx
    inc dx
    dec bx
    jnz .win_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW ENEMY CAR ============
draw_enemy_car:
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
    
    mov al, bl
    push ax
    
    push dx
    mov bx, dx
    add bx, 25
    
.enemy_body_y:
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
    mov bx, 20
    mov al, [esp+4]
.enemy_body_x:
    mov [es:di], al
    inc di
    dec bx
    jnz .enemy_body_x
    pop bx
    
    inc dx
    cmp dx, bx
    jb .enemy_body_y
    
    pop dx
    pop ax
    
    ; Wheels
    push dx
    add dx, 3
    mov bx, 8
.elw1:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    sub cx, 3
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .elw1
    pop dx
    
    push dx
    add dx, 3
    mov bx, 8
.erw1:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    add cx, 20
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .erw1
    pop dx
    
    push dx
    add dx, 17
    mov bx, 8
.elw2:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    sub cx, 3
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .elw2
    pop dx
    
    push dx
    add dx, 17
    mov bx, 8
.erw2:
    push dx
    mov ax, dx
    mov cx, 320
    mul cx
    mov cx, si
    add cx, 20
    add ax, cx
    mov di, ax
    mov byte [es:di], 0
    mov byte [es:di+1], 0
    mov byte [es:di+2], 0
    pop dx
    inc dx
    dec bx
    jnz .erw2
    pop dx
    
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ SPAWN ENEMY CAR (ONLY IN LANES) ============
spawn_enemy:
    push ax
    push bx
    push si
    push cx
    
    mov ax, [spawndelay]
    cmp ax, 0
    je .can_spawn
    dec word [spawndelay]
    jmp .skipspawn
    
.can_spawn:
    call get_random
    and al, 0x1F
    cmp al, 5
    jg .skipspawn
    
    mov al, [numcars]
    cmp al, 3
    jge .skipspawn
    
    mov si, enemycars
    mov cx, 5
    
.findempty:
    cmp byte [si+3], 0
    je .foundempty
    add si, 4
    loop .findempty
    jmp .skipspawn
    
.foundempty:
    ; Generate random lane (0, 1, or 2)
    call get_random
    xor ah, ah
    mov bl, 3
    div bl
    mov [si], ah  ; Store lane number (0, 1, or 2)
    
    mov word [si+1], -50
    mov byte [si+3], 1
    
    inc byte [numcars]
    
    mov ax, [enemy_spawn_delay]
    mov [spawndelay], ax
    
.skipspawn:
    pop cx
    pop si
    pop bx
    pop ax
    ret

; ============ SPAWN BONUS ============
spawn_bonus:
    push ax
    push bx
    push cx
    push dx
    push si
    
    cmp byte [bonusactive], 1
    je .skipbonus
    
    call get_random
    and ax, 0x0FF
    mov bx, [bonus_spawn_chance]
    cmp ax, bx
    jg .skipbonus
    
    ; Check occupied lanes
    mov si, enemycars
    mov cx, 5
    mov bx, 0
    
.check_occupied_lanes:
    cmp byte [si+3], 0
    je .lane_not_occupied
    mov al, [si]
    mov ah, 1
    mov cl, al
    shl ah, cl
    or bl, ah
.lane_not_occupied:
    add si, 4
    loop .check_occupied_lanes
    
    ; Find empty lane
    mov cx, 3
.find_empty_lane:
    call get_random
    xor ah, ah
    mov dl, 3
    div dl
    mov [bonuslane], ah
    
    mov al, 1
    mov dl, ah
    mov cl, dl
    shl al, cl
    test bl, al
    jz .lane_is_free
    
    loop .find_empty_lane
    
    jmp .skipbonus
    
.lane_is_free:
    mov word [bonusy], -20
    mov byte [bonusactive], 1
    
.skipbonus:
    pop si
    pop dx
    pop cx
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
    
.drawnext:
    cmp byte [si+3], 0
    je .skipthis
    
    ; Get lane position
    movzx bx, byte [si]
    shl bx, 1
    mov ax, [lanepositions+bx]

    mov dx, [si+1]
    
    cmp dx, -20
    jl .skipthis
    cmp dx, 200
    jge .skipthis
    
    ; Check bonus overlap
    cmp byte [bonusactive], 0
    je .no_bonus_overlap
    
    mov bp, [bonusy]
    sub bp, 25
    cmp dx, bp
    jl .no_bonus_overlap
    
    mov bp, [bonusy]
    add bp, 25
    cmp dx, bp
    jg .no_bonus_overlap
    
    mov al, [si]
    cmp al, [bonuslane]
    je .skipthis
    
.no_bonus_overlap:
    push si
    push cx
    
    ; Alternate colors
    mov cx, si
    sub cx, enemycars
    shr cx, 2
    and cx, 1
    jz .use_blue
    mov bl, 14
    jmp .draw_it
.use_blue:
    mov bl, 1
.draw_it:
    call draw_enemy_car
    
    pop cx
    pop si
    
.skipthis:
    add si, 4
    loop .drawnext
    
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
    je .skipbonus2
    
    mov ax, 0xA000
    mov es, ax
    
    movzx bx, byte [bonuslane]
    shl bx, 1
    mov cx, [lanepositions+bx]
    sub cx, 4
    
    mov dx, [bonusy]
    
    cmp dx, -20
    jl .skipbonus2
    cmp dx, 200
    jge .skipbonus2
    
    ; Draw bonus as yellow diamond
    push dx
    mov bx, 8
.bonus_row:
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
.bonus_pix:
    mov byte [es:di], 14
    inc di
    dec bx
    jnz .bonus_pix
    pop bx
    
    inc dx
    dec bx
    jnz .bonus_row
    pop dx
    
.skipbonus2:
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
    
.updatenext:
    cmp byte [si+3], 0
    je .skipupdate
    
    mov ax, [enemy_speed]
    add [si+1], ax
    
    mov ax, [si+1]
    cmp ax, 220
    jl .skipupdate
    
    mov byte [si+3], 0
    dec byte [numcars]
    
.skipupdate:
    add si, 4
    loop .updatenext
    
    pop ax
    pop cx
    pop si
    ret

; ============ UPDATE BONUS ============
update_bonus:
    push ax
    
    cmp byte [bonusactive], 0
    je .skipupdate_bonus
    
    mov ax, [bonus_speed]
    add [bonusy], ax
    
    mov ax, [bonusy]
    cmp ax, 220
    jl .skipupdate_bonus
    
    mov byte [bonusactive], 0
    
.skipupdate_bonus:
    pop ax
    ret

; ============ CHECK COLLISION ============
check_collision:
    push si
    push ax
    push bx
    push cx
    push dx
    
    ; Check bonus
    cmp byte [bonusactive], 0
    je .check_enemies
    
    mov ax, [bonusy]
    add ax, 8
    
    cmp ax, 175
    jl .check_enemies
    cmp ax, 200
    jg .check_enemies
    
    mov al, [carlane]
    cmp al, [bonuslane]
    jne .check_enemies
    
    add word [score], 50
    mov byte [bonusactive], 0
    
.check_enemies:
    mov si, enemycars
    mov cx, 5
    
.checknext:
    cmp byte [si+3], 0
    je .skipcheck
    
    mov ax, [si+1]
    add ax, 12
    
    cmp ax, 175
    jl .skipcheck
    cmp ax, 200
    jg .skipcheck
    
    mov al, [carlane]
    cmp al, [si]
    jne .skipcheck
    
    mov byte [gameover], 1
    
.skipcheck:
    add si, 4
    loop .checknext
    
    pop dx
    pop cx
    pop bx
    pop ax
    pop si
    ret

; ============ SHOW SCORE IN BLACK BOX ============
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
    
    ; Draw black score box at top
    mov dx, 2
    mov cx, 8
.clear_score_y:
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 230
    mov di, ax
    pop dx
    
    push cx
    mov cx, 80
    mov al, 0
.clear_score_x:
    mov [es:di], al
    inc di
    loop .clear_score_x
    pop cx
    
    inc dx
    loop .clear_score_y
    
    ; Draw "SCORE:" text in white
    mov di, 232
    call draw_small_text
    
    ; Display score number
    mov ax, [score]
    mov bx, 10
    mov cx, 0
    
.get_digits:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne .get_digits
    
    cmp cx, 0
    jne .has_digits
    push 0
    inc cx
    
.has_digits:
    mov di, 275
    
.draw_score_digits:
    pop dx
    push cx
    push di
    
    mov ax, dx
    call draw_digit_small
    
    pop di
    add di, 7
    pop cx
    loop .draw_score_digits
    
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw "SCORE:" text
draw_small_text:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov dx, 4
    mov bx, 5
.text_loop:
    push bx
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, di
    mov di, ax
    
    mov cx, 35
    mov al, 15
.text_pixel:
    mov [es:di], al
    inc di
    loop .text_pixel
    
    pop dx
    inc dx
    pop bx
    dec bx
    jnz .text_loop
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw small digit for score
draw_digit_small:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    mov bx, ax
    mov dx, 3
    
    mov ax, bx
    mov cx, 15
    mul cx
    mov si, ax
    add si, digit_patterns_small
    
    mov cx, 5
.draw_row:
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
    
    mov cx, 3
.draw_col:
    lodsb
    cmp al, 0
    je .skip_pixel
    mov byte [es:di], 15
.skip_pixel:
    inc di
    loop .draw_col
    
    pop dx
    inc dx
    pop di
    pop cx
    loop .draw_row
    
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Small digit patterns (3x5)
digit_patterns_small:
    ; 0
    db 1,1,1
    db 1,0,1
    db 1,0,1
    db 1,0,1
    db 1,1,1
    ; 1
    db 0,1,0
    db 1,1,0
    db 0,1,0
    db 0,1,0
    db 1,1,1
    ; 2
    db 1,1,1
    db 0,0,1
    db 1,1,1
    db 1,0,0
    db 1,1,1
    ; 3
    db 1,1,1
    db 0,0,1
    db 1,1,1
    db 0,0,1
    db 1,1,1
    ; 4
    db 1,0,1
    db 1,0,1
    db 1,1,1
    db 0,0,1
    db 0,0,1
    ; 5
    db 1,1,1
    db 1,0,0
    db 1,1,1
    db 0,0,1
    db 1,1,1
    ; 6
    db 1,1,1
    db 1,0,0
    db 1,1,1
    db 1,0,1
    db 1,1,1
    ; 7
    db 1,1,1
    db 0,0,1
    db 0,1,0
    db 0,1,0
    db 0,1,0
    ; 8
    db 1,1,1
    db 1,0,1
    db 1,1,1
    db 1,0,1
    db 1,1,1
    ; 9
    db 1,1,1
    db 1,0,1
    db 1,1,1
    db 0,0,1
    db 1,1,1
