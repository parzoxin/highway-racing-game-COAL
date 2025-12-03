org 0x0100

jmp start

; ============ GAME STATE ============
gameState    db 0    ; 0 = start screen, 1 = playing, 2 = game over, 3 = end screen

; ============ GAME STATE ============
score        dw 0
fuel         dw 100

; Add these near the top with other game state variables
gameOverText db 'GAME OVER!', 0
scoreText    db 'Score: ', 0
fuelText     db 'Fuel: ', 0

;==========For Pause purposes==========
pausedText          db 'PAUSED', 0
pausePromptText     db 'End Game? Y/N', 0
resumeText          db 'Press ESC to Resume', 0

;======For ending the gamne=======
finalScoreLabel db 'Final Score:', 0
finalFuelLabel  db 'Final Fuel:', 0
exitPromptText  db 'Press any key to return to menu', 0

; ============ CONFIGURABLE SETTINGS ============

; GAME SPEED SETTINGS (1-5, higher = faster)
; 1 = Very Slow, 2 = Normal, 3 = Fast, 4 = Very Fast, 5 = Extreme
GAME_SPEED equ 2

; SPAWN RATES (frames between spawns, higher = less frequent)
; -------------------------------------------------------------
ENEMY_SPAWN_RATE    equ 40    ; Enemies spawn every 40 frames
COIN_SPAWN_RATE     equ 60    ; Coins spawn every 90 frames
FUEL_SPAWN_RATE     equ 150   ; Fuel spawns every 150 frames

; GAME BALANCE SETTINGS
; ----------------------
SCORE_PER_COIN      equ 10    ; Points per coin collected
FUEL_PER_CAN        equ 10    ; Fuel per fuel can collected
FUEL_DECREASE_RATE  equ 40    ; Frames between fuel decrease (higher = slower decrease)
INITIAL_FUEL        equ 100   ; Starting fuel amount

; PLAYER BOUNDARIES
; -----------------
PLAYER_MIN_X        equ 85    ; Leftmost position player can go
PLAYER_MAX_X        equ 216   ; Rightmost position player can go

; ============ COLLISION DETECTION ============

CheckEnemyCollision:
    push ax
    push bx
    push cx
    push dx
    push si

    xor bx, bx                 ; enemy index

.nextEnemy:
    cmp bx, MAX_ENEMIES
    jae .done
    
    mov al, [enemyActive + bx]
    cmp al, 0
    je .skipEnemy

    ; Get enemy position
    push bx
    shl bx, 1
    mov ax, [enemyX + bx]      ; enemy X in AX
    mov si, [enemyY + bx]      ; enemy Y in SI
    pop bx

    ; Check X-axis overlap (player X ± 12 vs enemy X ± 12)
    mov cx, [playerX]
    sub cx, ax                 ; CX = playerX - enemyX
    jns .xPositive
    neg cx
.xPositive:
    cmp cx, 10                 ; If distance > 20, no collision (FIXED: Use original value)
    ja .skipEnemy

    ; Check Y-axis overlap (player Y ± 14 vs enemy Y ± 14)
    mov dx, [playerY]
    sub dx, si                 ; DX = playerY - enemyY
    jns .yPositive
    neg dx
.yPositive:
    cmp dx, 14                 ; If distance > 24, no collision (FIXED: Use original value)
    ja .skipEnemy

    ; ===== COLLISION DETECTED =====
    mov byte [gameState], 2    ; GAME OVER
    call ShowGameOver
    jmp .done

.skipEnemy:
    inc bx
    jmp .nextEnemy

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

CheckCoinCollision:
    push ax
    push bx
    push cx
    push dx
    push si

    xor bx, bx                 ; coin index

.nextCoin:
    cmp bx, MAX_COINS
    jae .done
    
    mov al, [coinActive + bx]
    cmp al, 0
    je .skipCoin

    ; Get coin position
    push bx
    shl bx, 1
    mov ax, [coinX + bx]       ; coin X in AX
    mov si, [coinY + bx]       ; coin Y in SI
    pop bx

    ; Check X-axis overlap
    mov cx, [playerX]
    add cx, 6                  ; Center of player car
    sub cx, ax
    sub cx, 2                  ; Center of coin (5/2)
    jns .xPositive
    neg cx
.xPositive:
    cmp cx, 10                 ; Collision threshold (FIXED: Use original value)
    ja .skipCoin

    ; Check Y-axis overlap
    mov dx, [playerY]
    add dx, 7                  ; Center of player car
    sub dx, si
    sub dx, 2                  ; Center of coin
    jns .yPositive
    neg dx
.yPositive:
    cmp dx, 12                 ; Collision threshold (FIXED: Use original value)
    ja .skipCoin

    ; ===== COIN COLLECTED =====
    mov byte [coinActive + bx], 0  ; Deactivate coin
    add word [score], SCORE_PER_COIN ; Add points using configurable setting
    
    ; Erase the coin
    push bx
    push ax
    push si
    shl bx, 1
    mov ax, [coinY + bx]
    mov si, [coinX + bx]
    call CalcOffset
    mov bx, 5
    mov cx, 5
    call EraseSprite
    pop si
    pop ax
    pop bx

.skipCoin:
    inc bx
    jmp .nextCoin

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

CheckFuelCollision:
    push ax
    push bx
    push cx
    push dx
    push si

    xor bx, bx                 ; fuel index

.nextFuel:
    cmp bx, MAX_FUEL
    jae .done
    
    mov al, [fuelActive + bx]
    cmp al, 0
    je .skipFuel

    ; Get fuel position
    push bx
    shl bx, 1
    mov ax, [fuelX + bx]       ; fuel X in AX
    mov si, [fuelY + bx]       ; fuel Y in SI
    pop bx

    ; Check X-axis overlap
    mov cx, [playerX]
    add cx, 6                  ; Center of player car
    sub cx, ax
    sub cx, 5                  ; Center of fuel (10/2)
    jns .xPositive
    neg cx
.xPositive:
    cmp cx, 12                 ; Collision threshold (FIXED: Use original value)
    ja .skipFuel

    ; Check Y-axis overlap
    mov dx, [playerY]
    add dx, 7                  ; Center of player car
    sub dx, si
    sub dx, 5                  ; Center of fuel
    jns .yPositive
    neg dx
.yPositive:
    cmp dx, 15                 ; Collision threshold (FIXED: Use original value)
    ja .skipFuel

    ; ===== FUEL COLLECTED =====
    mov byte [fuelActive + bx], 0  ; Deactivate fuel
    add word [fuel], FUEL_PER_CAN  ; Add fuel using configurable setting
    
    ; Cap fuel at 100
    cmp word [fuel], 100
    jbe .fuelOk
    mov word [fuel], 100
.fuelOk:
    
    ; Erase the fuel
    push bx
    push ax
    push si
    shl bx, 1
    mov ax, [fuelY + bx]
    mov si, [fuelX + bx]
    call CalcOffset
    mov bx, 10
    mov cx, 10
    call EraseSprite
    pop si
    pop ax
    pop bx

.skipFuel:
    inc bx
    jmp .nextFuel

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ShowGameOver:
    push ax
    push bx
    push di
    
    ; Display "GAME OVER!" in center of screen
    mov di, 320 * 90 + 120
    mov bx, gameOverText
    mov al, 12                 ; Red color
    call DrawText
    
    pop di
    pop bx
    pop ax
    ret


; ============ SCORE AND FUEL DISPLAY ============

DrawScore:
    push ax
    push bx
    push cx
    push di
    push si
    
    ; Clear score area first (top left, 50 pixels wide, 10 pixels tall)
    mov di, 320 * 5 + 85
    mov cx, 10          ; 10 rows
.clearLoop:
    push di
    mov ax, 50          ; 50 pixels wide
    mov bx, ax
.clearInner:
    mov byte [es:di], 9 ; Light blue (background color)
    inc di
    dec bx
    jnz .clearInner
    pop di
    add di, 320
    loop .clearLoop
    
    ; Draw "Score: " at top left
    mov di, 320 * 5 + 85
    mov bx, scoreText
    mov al, 15                 ; White
    call DrawText
    
    ; Draw score value (4 digit number)
    mov ax, [score]
    mov di, 320 * 5 + 127
    call DrawNumber
    
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    ret

DrawFuelBar:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    ; Clear fuel area first (top right, 80 pixels wide, 10 pixels tall)
    mov di, 320 * 5 + 200
    mov cx, 10          ; 10 rows
.clearLoop:
    push di
    mov ax, 80          ; 80 pixels wide
    mov bx, ax
.clearInner:
    mov byte [es:di], 9 ; Light blue
    inc di
    dec bx
    jnz .clearInner
    pop di
    add di, 320
    loop .clearLoop
    
    ; Draw "Fuel: " at top right
    mov di, 320 * 5 + 200
    mov bx, fuelText
    mov al, 15                 ; White
    call DrawText
    
    ; Draw fuel bar as pixels (fuel/2 = 0-50 pixels)
    mov ax, [fuel]
    shr ax, 1                  ; Divide by 2 to get 0-50 range
    mov cx, ax
    mov di, 320 * 5 + 236
    
.drawBar:
    cmp cx, 0
    je .done
    mov byte [es:di], 14       ; Yellow for fuel
    inc di
    dec cx
    jmp .drawBar
    
.done:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DrawNumber:
    ; Draw number in AX at DI position
    ; AX = number to draw, DI = screen offset, BL = color
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov si, 10
    xor cx, cx                 ; Digit counter
    mov bx, 15                 ; White color
    
.divLoop:
    xor dx, dx
    div si                     ; AX = AX / 10, DX = remainder (digit)
    push dx                    ; Save digit
    inc cx
    cmp ax, 0
    jne .divLoop
    
.drawLoop:
    pop ax
    add al, '0'                ; Convert to ASCII
    push cx
    push di
    call DrawChar              ; Draws at DI
    pop di
    pop cx
    add di, 6                  ; Move 6 pixels right for next digit
    loop .drawLoop
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret




DecreaseFuel:
    push ax
    push bx
    
    ; Decrease fuel every FUEL_DECREASE_RATE frames
    inc byte [fuelDecreaseCounter]
    mov al, [fuelDecreaseCounter]
    cmp al, FUEL_DECREASE_RATE
    jb .noDecrease
    
    ; Reset counter
    mov byte [fuelDecreaseCounter], 0
    
    cmp word [fuel], 0
    je .gameOver
    
    dec word [fuel]
    jmp .done
    
.gameOver:
    mov byte [gameState], 2
    call ShowGameOver
    
.noDecrease:
.done:
    pop bx
    pop ax
    ret
	
	
; ============ PLAYER DATA ============
playerX      dw 154
playerY      dw 170

; ============ ENEMY ARRAYS (5 enemies max) ============
MAX_ENEMIES  equ 5
enemyX       dw 0,0,0,0,0
enemyY       dw 0,0,0,0,0
enemyActive  db 0,0,0,0,0

; ============ COIN ARRAYS (3 coins max) ============
MAX_COINS    equ 3
coinX        dw 0,0,0
coinY        dw 0,0,0
coinActive   db 0,0,0

; ============ FUEL ARRAYS (2 fuel max) ============
MAX_FUEL     equ 2
fuelX        dw 0,0
fuelY        dw 0,0
fuelActive   db 0,0

; ============ TIMERS ============
spawnTimer     db 0
spawnCoinTimer db 0
spawnFuelTimer db 0
fuelDecreaseCounter db 0  
; ============ SCROLLING ============
stripeOffset   db 0
frameCounter   db 0

; ============ LANE POSITIONS (3 lanes only) ============
; Adjusted for 3 lanes instead of 4
lane1X      equ 94    ; Left lane
lane2X      equ 140   ; Center lane
lane3X      equ 186   ; Right lane

; ============ SPRITES ============

; Large car sprite for start screen (24x28 pixels)
LargeCarSprite:
db 255,255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255
db 255,0,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0,255
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,4,8,0
db 0,8,4,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,4,8,0
db 0,8,4,7,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,7,4,8,0
db 0,8,4,7,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,7,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,0
db 0,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0
db 255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255
db 255,255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255
db 255,255,255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,255
db 255,255,255,255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,255,255

TreeSprite:
db 2,2,2,2,2,6,6,6,6,2,2,2
db 2,2,2,6,6,10,10,10,10,6,6,2
db 2,2,6,10,10,10,10,10,10,10,6,2
db 2,6,10,10,10,10,10,10,10,10,10,6
db 6,10,10,10,10,10,10,10,10,10,10,6
db 6,10,10,10,10,10,10,10,10,10,10,6
db 6,10,10,10,10,10,10,10,10,10,10,6
db 2,6,10,10,10,10,10,10,10,10,6,2
db 2,2,6,10,10,10,10,10,10,6,2,2
db 2,2,2,6,6,10,10,6,6,2,2,2
db 2,2,2,2,2,6,6,2,2,2,2,2
db 2,2,2,2,2,6,6,2,2,2,2,2
db 2,2,2,2,2,6,6,2,2,2,2,2
db 2,2,2,2,2,6,6,2,2,2,2,2
db 2,2,2,2,2,6,6,2,2,2,2,2
db 2,2,2,2,2,6,6,2,2,2,2,2
db 2,2,2,2,6,6,6,6,2,2,2,2
db 2,2,2,2,6,6,6,6,2,2,2,2

FlowerSpriteOrange:
db 12,12,12,12,12,12,12
db 12,12,12,12,12,12,12
db 12,12,12,12,12,12,12
db 12,12,12,12,12,12,12
db 12,12,12,12,12,12,12
db 2,12,12,12,12,12,2
db 2,2,10,10,10,2,2

RockSprite:
db 8,7,7,7,8,2
db 7,8,8,8,7,8
db 8,7,7,7,8,7
db 2,8,8,8,7,2

CarModel:
db 255,0,0,0,0,0,0,0,0,0,0,255
db 0,8,8,8,8,8,8,8,8,8,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,4,7,7,7,7,7,7,4,8,0
db 0,8,4,7,4,4,4,4,7,4,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,4,4,4,4,4,4,4,4,8,0
db 0,8,8,8,8,8,8,8,8,8,8,0
db 255,0,0,0,0,0,0,0,0,0,0,255

CarModelObstacle:
db 255,14,14,14,14,14,14,14,14,14,14,255
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 14,1,1,1,1,1,1,1,1,1,1,14
db 255,14,14,14,14,14,14,14,14,14,14,255
db 255,255,14,14,14,14,14,14,14,14,255,255

CoinModel:
    times 25 db 14

FuelModel:
    times 100 db 12

; ============ TEXT STRINGS ============
titleText       db 'HighWay Racing Game', 0
promptText      db 'Press any key to start', 0
instructText1   db 'Left key: Move Left', 0
instructText2   db 'Right key: Move Right', 0
; instructText3   db 'Up and down key for up and down', 0
creditsText     db 'Ahmad Babar 24L-0644 and Abdul Ahad Khan 24L-0954', 0

; ============ START SCREEN ============

DrawStartScreen:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Fill screen with light blue (color 9)
    xor di, di
    mov cx, 64000       ; 320 * 200 pixels
    mov al, 9           ; Light blue color
    
dssLoop:
    mov [es:di], al
    inc di
    loop dssLoop
    
    ; Draw title "SAOWEII CARS" at top (Y=20, centered)
    mov di, 320 * 20 + 104  ; Center position for 12 chars (12*6=72, 320/2-72/2=124)
    mov bx, titleText
    mov al, 15          ; White color
    call DrawText
    
    ; Draw large car sprite (centered at Y=60)
    mov di, 320 * 60 + 148  ; Center position (320/2 - 24/2 = 148)
    call DrawLargeCar
    
    ; Draw "Press any key to start" (Y=120, centered)
    mov di, 320 * 120 + 77  ; Center for 22 chars (22*6=132, 320/2-132/2=94)
    mov bx, promptText
    mov al, 0           ; Black color
    call DrawText
    
    ; Draw instruction text "Left key: Move Left" (Y=145)
    mov di, 320 * 145 + 82
    mov bx, instructText1
    mov al, 4           ; Red color
    call DrawText
    
    ; Draw instruction text "Right key: Move Right" (Y=155)
    mov di, 320 * 155 + 76
    mov bx, instructText2
    mov al, 4           ; Red color
    call DrawText
    
    ; Draw credits at bottom (Y=185)
    mov di, 320 * 185 + 15  ; Starting from left side for long text
    mov bx, creditsText
    mov al, 0           ; Black color
    call DrawText
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw large car sprite at DI offset
DrawLargeCar:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov bx, LargeCarSprite
    mov cx, 28          ; 28 rows
    
dlcRow:
    cmp cx, 0
    je dlcExit
    push di
    mov dx, 24          ; 24 columns
    
dlcCol:
    cmp dx, 0
    je dlcDone
    mov al, [bx]
    cmp al, 255         ; Skip transparent pixels
    je dlcSkip
    mov [es:di], al
    
dlcSkip:
    inc bx
    inc di
    dec dx
    jmp dlcCol
    
dlcDone:
    pop di
    add di, 320
    dec cx
    jmp dlcRow
    
dlcExit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw text string at DI offset, BX = string pointer, AL = color
DrawText:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    mov si, bx          ; SI points to string
    mov bl, al          ; Save color in BL
    
dtLoop:
    mov al, [si]        ; Get character
    cmp al, 0           ; Check for null terminator
    je dtExit
    
    ; Save registers before DrawChar
    push si
    push di
    push bx
    
    ; Draw character (simple 5x7 font simulation using pixels)
    call DrawChar
    
    ; Restore registers
    pop bx
    pop di
    pop si
    
    add di, 6           ; Move to next character position (5 + 1 spacing)
    inc si              ; Next character in string
    jmp dtLoop
    
dtExit:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw a single character at DI, AL = ASCII char, BL = color
DrawChar:
    push ax
    push cx
    push dx
    push di
    
    ; Simple block font for uppercase letters and space
    cmp al, 'A'
    jne dcNotA
    jmp dcA
dcNotA:
    cmp al, 'B'
    jne dcNotB
    jmp dcB
dcNotB:
    cmp al, 'C'
    jne dcNotC
    jmp dcC
dcNotC:
    cmp al, 'D'
    jne dcNotD
    jmp dcD
dcNotD:
    cmp al, 'E'
    jne dcNotE
    jmp dcE
dcNotE:
    cmp al, 'F'
    jne dcNotF
    jmp dcF
dcNotF:
    cmp al, 'G'
    jne dcNotG
    jmp dcG
dcNotG:
    cmp al, 'H'
    jne dcNotH
    jmp dcH
dcNotH:
    cmp al, 'I'
    jne dcNotI
    jmp dcI
dcNotI:
    cmp al, 'J'
    jne dcNotJ
    jmp dcJ
dcNotJ:
    cmp al, 'K'
    jne dcNotK
    jmp dcK
dcNotK:
    cmp al, 'L'
    jne dcNotL
    jmp dcL
dcNotL:
    cmp al, 'M'
    jne dcNotM
    jmp dcM
dcNotM:
    cmp al, 'N'
    jne dcNotN
    jmp dcN
dcNotN:
    cmp al, 'O'
    jne dcNotO
    jmp dcO
dcNotO:
    cmp al, 'P'
    jne dcNotP
    jmp dcP
dcNotP:
    cmp al, 'Q'
    jne dcNotQ
    jmp dcQ
dcNotQ:
    cmp al, 'R'
    jne dcNotR
    jmp dcR
dcNotR:
    cmp al, 'S'
    jne dcNotS
    jmp dcS
dcNotS:
    cmp al, 'T'
    jne dcNotT
    jmp dcT
dcNotT:
    cmp al, 'U'
    jne dcNotU
    jmp dcU
dcNotU:
    cmp al, 'V'
    jne dcNotV
    jmp dcV
dcNotV:
    cmp al, 'W'
    jne dcNotW
    jmp dcW
dcNotW:
    cmp al, 'X'
    jne dcNotX
    jmp dcX
dcNotX:
    cmp al, 'Y'
    jne dcNotY
    jmp dcY
dcNotY:
    cmp al, 'Z'
    jne dcNotZ
    jmp dcZ
dcNotZ:
    ; Lowercase letters
    cmp al, 'a'
    jne dcNotLowerA
    jmp dcLowerA
dcNotLowerA:
    cmp al, 'b'
    jne dcNotLowerB
    jmp dcLowerB
dcNotLowerB:
    cmp al, 'c'
    jne dcNotLowerC
    jmp dcLowerC
dcNotLowerC:
    cmp al, 'd'
    jne dcNotLowerD
    jmp dcLowerD
dcNotLowerD:
    cmp al, 'e'
    jne dcNotLowerE
    jmp dcLowerE
dcNotLowerE:
    cmp al, 'f'
    jne dcNotLowerF
    jmp dcLowerF
dcNotLowerF:
    cmp al, 'g'
    jne dcNotLowerG
    jmp dcLowerG
dcNotLowerG:
    cmp al, 'h'
    jne dcNotLowerH
    jmp dcLowerH
dcNotLowerH:
    cmp al, 'i'
    jne dcNotLowerI
    jmp dcLowerI
dcNotLowerI:
    cmp al, 'j'
    jne dcNotLowerJ
    jmp dcLowerJ
dcNotLowerJ:
    cmp al, 'k'
    jne dcNotLowerK
    jmp dcLowerK
dcNotLowerK:
    cmp al, 'l'
    jne dcNotLowerL
    jmp dcLowerL
dcNotLowerL:
    cmp al, 'm'
    jne dcNotLowerM
    jmp dcLowerM
dcNotLowerM:
    cmp al, 'n'
    jne dcNotLowerN
    jmp dcLowerN
dcNotLowerN:
    cmp al, 'o'
    jne dcNotLowerO
    jmp dcLowerO
dcNotLowerO:
    cmp al, 'p'
    jne dcNotLowerP
    jmp dcLowerP
dcNotLowerP:
    cmp al, 'q'
    jne dcNotLowerQ
    jmp dcLowerQ
dcNotLowerQ:
    cmp al, 'r'
    jne dcNotLowerR
    jmp dcLowerR
dcNotLowerR:
    cmp al, 's'
    jne dcNotLowerS
    jmp dcLowerS
dcNotLowerS:
    cmp al, 't'
    jne dcNotLowerT
    jmp dcLowerT
dcNotLowerT:
    cmp al, 'u'
    jne dcNotLowerU
    jmp dcLowerU
dcNotLowerU:
    cmp al, 'v'
    jne dcNotLowerV
    jmp dcLowerV
dcNotLowerV:
    cmp al, 'w'
    jne dcNotLowerW
    jmp dcLowerW
dcNotLowerW:
    cmp al, 'x'
    jne dcNotLowerX
    jmp dcLowerX
dcNotLowerX:
    cmp al, 'y'
    jne dcNotLowerY
    jmp dcLowerY
dcNotLowerY:
    cmp al, 'z'
    jne dcNotLowerZ
    jmp dcLowerZ
dcNotLowerZ:
    ; Digits 0-9
    cmp al, '0'
    jne dcNot0
    jmp dc0
dcNot0:
    cmp al, '1'
    jne dcNot1
    jmp dc1
dcNot1:
    cmp al, '2'
    jne dcNot2
    jmp dc2
dcNot2:
    cmp al, '3'
    jne dcNot3
    jmp dc3
dcNot3:
    cmp al, '4'
    jne dcNot4
    jmp dc4
dcNot4:
    cmp al, '5'
    jne dcNot5
    jmp dc5
dcNot5:
    cmp al, '6'
    jne dcNot6
    jmp dc6
dcNot6:
    cmp al, '7'
    jne dcNot7
    jmp dc7
dcNot7:
    cmp al, '8'
    jne dcNot8
    jmp dc8
dcNot8:
    cmp al, '9'
    jne dcNot9
    jmp dc9
dcNot9:
    ; Symbols
    cmp al, '-'
    jne dcNotDash
    jmp dcDash
dcNotDash:
    cmp al, '('
    jne dcNotLParen
    jmp dcLParen
dcNotLParen:
    cmp al, ')'
    jne dcNotRParen
    jmp dcRParen
dcNotRParen:
    cmp al, ':'
    jne dcNotColon
    jmp dcColon
dcNotColon:
    cmp al, ' '
    jne dcNotSpace
    jmp dcSpace
dcNotSpace:
    cmp al, '.'
    jne dcNotPeriod
    jmp dcPeriod
dcNotPeriod:
    cmp al, ','
    jne dcNotComma
    jmp dcComma
dcNotComma:
    cmp al, '!'
    jne dcNotExcl
    jmp dcExcl
dcNotExcl:
    cmp al, '?'
    jne dcNotQuestion
    jmp dcQuestion
dcNotQuestion:
    jmp dcCharDone

; Character patterns (simplified 5x7 pixel fonts)
dcA:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    jmp dcCharDone
    
dcB:
    call DrawPattern5x7
    db 1,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,0
    jmp dcCharDone
    
dcC:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcD:
    call DrawPattern5x7
    db 1,1,1,0,0
    db 1,0,0,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,1,0
    db 1,1,1,0,0
    jmp dcCharDone
    
dcE:
    call DrawPattern5x7
    db 1,1,1,1,1
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,1,1,1,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,1,1,1,1
    jmp dcCharDone
    
dcF:
    call DrawPattern5x7
    db 1,1,1,1,1
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,1,1,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    jmp dcCharDone
    
dcG:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,1,1,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcH:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    jmp dcCharDone
    
dcI:
    call DrawPattern5x7
    db 1,1,1,1,1
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 1,1,1,1,1
    jmp dcCharDone
    
dcJ:
    call DrawPattern5x7
    db 0,0,0,0,1
    db 0,0,0,0,1
    db 0,0,0,0,1
    db 0,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcK:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,0,0,1,0
    db 1,0,1,0,0
    db 1,1,0,0,0
    db 1,0,1,0,0
    db 1,0,0,1,0
    db 1,0,0,0,1
    jmp dcCharDone
    
dcL:
    call DrawPattern5x7
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,1,1,1,1
    jmp dcCharDone
    
dcM:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,1,0,1,1
    db 1,0,1,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    jmp dcCharDone
    
dcN:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,1,0,0,1
    db 1,0,1,0,1
    db 1,0,0,1,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    jmp dcCharDone
    
dcO:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcP:
    call DrawPattern5x7
    db 1,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    jmp dcCharDone
    
dcQ:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,1,0,1
    db 1,0,0,1,0
    db 0,1,1,0,1
    jmp dcCharDone
    
dcR:
    call DrawPattern5x7
    db 1,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,0
    db 1,0,1,0,0
    db 1,0,0,1,0
    db 1,0,0,0,1
    jmp dcCharDone
    
dcS:
    call DrawPattern5x7
    db 0,1,1,1,1
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 0,1,1,1,0
    db 0,0,0,0,1
    db 0,0,0,0,1
    db 1,1,1,1,0
    jmp dcCharDone
    
dcT:
    call DrawPattern5x7
    db 1,1,1,1,1
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    jmp dcCharDone
    
dcU:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcV:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,0,1,0
    db 0,1,0,1,0
    db 0,0,1,0,0
    jmp dcCharDone
    
dcW:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,1,0,1
    db 1,0,1,0,1
    db 1,1,0,1,1
    db 0,1,0,1,0
    jmp dcCharDone

dcX:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 0,1,0,1,0
    db 0,1,0,1,0
    db 0,0,1,0,0
    db 0,1,0,1,0
    db 0,1,0,1,0
    db 1,0,0,0,1
    jmp dcCharDone

dcY:
    call DrawPattern5x7
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,0,1,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    jmp dcCharDone

dcZ:
    call DrawPattern5x7
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    db 1,0,0,0,0
    db 1,1,1,1,1
    jmp dcCharDone

; Lowercase letters
dcLowerA:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,1,1,1,0
    db 0,0,0,0,1
    db 0,1,1,1,1
    db 1,0,0,0,1
    db 0,1,1,1,1
    jmp dcCharDone
    
dcLowerB:
    call DrawPattern5x7
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,1,1,0
    db 1,1,0,0,1
    db 1,0,0,0,1
    db 1,1,0,0,1
    db 1,0,1,1,0
    jmp dcCharDone
    
dcLowerC:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,0
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcLowerD:
    call DrawPattern5x7
    db 0,0,0,0,1
    db 0,0,0,0,1
    db 0,1,1,0,1
    db 1,0,0,1,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,1
    jmp dcCharDone
    
dcLowerE:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,1,1,1,1
    db 1,0,0,0,0
    db 0,1,1,1,0
    jmp dcCharDone
    
dcLowerF:
    call DrawPattern5x7
    db 0,0,1,1,0
    db 0,1,0,0,1
    db 0,1,0,0,0
    db 1,1,1,1,0
    db 0,1,0,0,0
    db 0,1,0,0,0
    db 0,1,0,0,0
    jmp dcCharDone
    
dcLowerG:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,1,1,1,1
    db 1,0,0,0,1
    db 0,1,1,1,1
    db 0,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcLowerH:
    call DrawPattern5x7
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,1,1,0
    db 1,1,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    jmp dcCharDone
    
dcLowerI:
    call DrawPattern5x7
    db 0,0,1,0,0
    db 0,0,0,0,0
    db 0,1,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,1,1,1,0
    jmp dcCharDone
    
dcLowerJ:
    call DrawPattern5x7
    db 0,0,0,1,0
    db 0,0,0,0,0
    db 0,0,1,1,0
    db 0,0,0,1,0
    db 0,0,0,1,0
    db 1,0,0,1,0
    db 0,1,1,0,0
    jmp dcCharDone
    
dcLowerK:
    call DrawPattern5x7
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,1,0
    db 1,0,1,0,0
    db 1,1,0,0,0
    db 1,0,1,0,0
    db 1,0,0,1,0
    jmp dcCharDone
    
dcLowerL:
    call DrawPattern5x7
    db 0,1,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,1
    db 0,0,0,1,0
    jmp dcCharDone
    
dcLowerM:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,1,0,1,0
    db 1,0,1,0,1
    db 1,0,1,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    jmp dcCharDone
    
dcLowerN:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,1,1,0
    db 1,1,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    jmp dcCharDone
    
dcLowerO:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcLowerP:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,1,1,0
    db 1,1,0,0,1
    db 1,0,0,0,1
    db 1,1,1,1,0
    db 1,0,0,0,0
    jmp dcCharDone
    
dcLowerQ:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,1,1,0,1
    db 1,0,0,1,1
    db 1,0,0,0,1
    db 0,1,1,1,1
    db 0,0,0,0,1
    jmp dcCharDone
    
dcLowerR:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,1,1,0
    db 1,1,0,0,1
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    jmp dcCharDone
    
dcLowerS:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,1,1,1,0
    db 1,0,0,0,0
    db 0,1,1,1,0
    db 0,0,0,0,1
    db 1,1,1,1,0
    jmp dcCharDone
    
dcLowerT:
    call DrawPattern5x7
    db 0,1,0,0,0
    db 0,1,0,0,0
    db 1,1,1,1,0
    db 0,1,0,0,0
    db 0,1,0,0,0
    db 0,1,0,0,1
    db 0,0,1,1,0
    jmp dcCharDone
    
dcLowerU:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,1,1
    db 0,1,1,0,1
    jmp dcCharDone
    
dcLowerV:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,0,1,0
    db 0,0,1,0,0
    jmp dcCharDone
    
dcLowerW:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,0,0,1
    db 1,0,1,0,1
    db 1,0,1,0,1
    db 1,1,0,1,1
    db 0,1,0,1,0
    jmp dcCharDone
    
dcLowerX:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,0,0,1
    db 0,1,0,1,0
    db 0,0,1,0,0
    db 0,1,0,1,0
    db 1,0,0,0,1
    jmp dcCharDone
    
dcLowerY:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,1
    db 0,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone
    
dcLowerZ:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,1,1,1,1
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    db 1,1,1,1,1
    jmp dcCharDone

; Digits
dc0:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,1,1
    db 1,0,1,0,1
    db 1,1,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone

dc1:
    call DrawPattern5x7
    db 0,0,1,0,0
    db 0,1,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,1,1,1,0
    jmp dcCharDone

dc2:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 0,0,0,0,1
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    db 1,1,1,1,1
    jmp dcCharDone

dc3:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 0,0,0,0,1
    db 0,0,1,1,0
    db 0,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone

dc4:
    call DrawPattern5x7
    db 0,0,0,1,0
    db 0,0,1,1,0
    db 0,1,0,1,0
    db 1,0,0,1,0
    db 1,1,1,1,1
    db 0,0,0,1,0
    db 0,0,0,1,0
    jmp dcCharDone

dc5:
    call DrawPattern5x7
    db 1,1,1,1,1
    db 1,0,0,0,0
    db 1,1,1,1,0
    db 0,0,0,0,1
    db 0,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone

dc6:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,0
    db 1,0,0,0,0
    db 1,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone

dc7:
    call DrawPattern5x7
    db 1,1,1,1,1
    db 0,0,0,0,1
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    db 0,1,0,0,0
    db 0,1,0,0,0
    jmp dcCharDone

dc8:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone

dc9:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,1
    db 0,0,0,0,1
    db 1,0,0,0,1
    db 0,1,1,1,0
    jmp dcCharDone

; Punctuation
dcDash:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 1,1,1,1,1
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    jmp dcCharDone

dcLParen:
    call DrawPattern5x7
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    db 0,1,0,0,0
    db 0,1,0,0,0
    db 0,0,1,0,0
    db 0,0,0,1,0
    jmp dcCharDone

dcRParen:
    call DrawPattern5x7
    db 0,1,0,0,0
    db 0,0,1,0,0
    db 0,0,0,1,0
    db 0,0,0,1,0
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    jmp dcCharDone

dcColon:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,0,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,0,0,0
    jmp dcCharDone

dcPeriod:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,1,0,0
    jmp dcCharDone

dcComma:
    call DrawPattern5x7
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,1,0,0,0
    jmp dcCharDone

dcExcl:
    call DrawPattern5x7
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,1,0,0
    db 0,0,0,0,0
    db 0,0,1,0,0
    jmp dcCharDone

dcQuestion:
    call DrawPattern5x7
    db 0,1,1,1,0
    db 1,0,0,0,1
    db 0,0,0,0,1
    db 0,0,0,1,0
    db 0,0,1,0,0
    db 0,0,0,0,0
    db 0,0,1,0,0
    jmp dcCharDone

dcSpace:
    ; Just skip pixels for space
    jmp dcCharDone

dcCharDone:
    pop di
    pop dx
    pop cx
    pop ax
    ret

; Helper to draw 5x7 character pattern
; Pattern data follows the call in caller's code
DrawPattern5x7:
    pop si              ; Get return address (points to pattern data)
    push ax
    push cx
    push dx
    push di
    
    mov cx, 7           ; 7 rows
dp5Row:
    push di
    mov dx, 5           ; 5 columns
dp5Col:
    mov al, [cs:si]     ; Read pattern byte
    inc si
    cmp al, 1
    jne dp5Skip
    mov al, bl          ; Use saved color
    mov [es:di], al
dp5Skip:
    inc di
    dec dx
    jnz dp5Col
    
    pop di
    add di, 320         ; Next row
    dec cx
    jnz dp5Row
    
    pop di
    pop dx
    pop cx
    pop ax
    push si             ; Push new return address
    ret

; ============ GAME SETUP ============

InitialSetup:
    ; Set VGA mode 13h (320x200, 256 colors)
    mov ax, 0x13
    int 0x10
    
    ; Set ES to video memory segment
    mov ax, 0xA000
    mov es, ax
    
    ; Draw game background
    call DrawBackground
    call DrawGrassSprites
    call LoadCar
    ret

DrawBackground:
    push ax
    push bx
    push cx
    push dx
    push di
    
    xor di, di
    mov cx, 200         ; 200 rows
    
bgLoop1:
    cmp cx, 0
    jne bgContinue
    jmp bgExit
bgContinue:
    push cx
    mov dx, 320         ; 320 columns
    
bgLoop2:
    cmp dx, 0
    je bgDone
    mov ax, 320
    sub ax, dx
    
    ; Check if we're in the border (left < 80 or right >= 240)
    cmp ax, 80
    jb bgDrawBorder
    cmp ax, 240
    jae bgDrawBorder
    jmp bgDrawRoad
    
bgDrawBorder:
    ; Alternating green stripes for grass border
    mov ax, 200
    pop bx
    push bx
    sub ax, bx
    mov bl, 5
    div bl
    test al, 1
    jz bgBorderLight
    mov byte [es:di], 2     ; Dark green
    jmp bgAfter
bgBorderLight:
    mov byte [es:di], 10    ; Light green
    jmp bgAfter
    
bgDrawRoad:
    mov byte [es:di], 8     ; Grey road
    
bgAfter:
    inc di
    dec dx
    jmp bgLoop2
    
bgDone:
    pop cx
    dec cx
    jmp bgLoop1
    
bgExit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DrawGrassSprites:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Trees on left side
    mov di,320*20+10
    call DrawTree
    mov di,320*60+25
    call DrawTree
    mov di,320*100+15
    call DrawTree
    mov di,320*140+30
    call DrawTree
    mov di,320*180+8
    call DrawTree
    
    ; Trees on right side
    mov di,320*30+265
    call DrawTree
    mov di,320*70+280
    call DrawTree
    mov di,320*110+270
    call DrawTree
    mov di,320*150+285
    call DrawTree
    
    ; Flowers on left side
    mov di,320*35+50
    call DrawFlower
    mov di,320*80+45
    call DrawFlower
    mov di,320*125+55
    call DrawFlower
    mov di,320*165+48
    call DrawFlower
    
    ; Flowers on right side
    mov di,320*45+250
    call DrawFlower
    mov di,320*90+258
    call DrawFlower
    mov di,320*135+252
    call DrawFlower
    
    ; Rocks on left side
    mov di,320*50+35
    call DrawRock
    mov di,320*120+40
    call DrawRock
    
    ; Rocks on right side
    mov di,320*65+300
    call DrawRock
    mov di,320*130+305
    call DrawRock
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ REDRAW GRASS IN PAUSE AREA ============
; Redraws grass sprites that might be in the pause screen area

RedrawGrassInPauseArea:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Check and redraw trees that might be in pause area (Y=60 to Y=140)
    ; Left side trees
    mov di,320*60+25
    call DrawTree
    mov di,320*100+15
    call DrawTree
    
    ; Right side trees
    mov di,320*70+280
    call DrawTree
    mov di,320*110+270
    call DrawTree
    
    ; Flowers in pause area
    mov di,320*80+45
    call DrawFlower
    mov di,320*125+55
    call DrawFlower
    
    ; Right side flowers
    mov di,320*90+258
    call DrawFlower
    
    ; Rocks in pause area
    mov di,320*120+40
    call DrawRock
    
    ; Right side rocks
    mov di,320*130+305
    call DrawRock
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DrawTree:
    push bx
    push cx
    push dx
    push di
    mov bx,TreeSprite
    mov cx,18           ; 18 rows
dtRow:
    cmp cx,0
    je dtDone
    push di
    mov dx,12           ; 12 columns
dtCol:
    cmp dx,0
    je dtNext
    mov al,[bx]
    mov [es:di],al
    inc bx
    inc di
    dec dx
    jmp dtCol
dtNext:
    pop di
    add di,320
    dec cx
    jmp dtRow
dtDone:
    pop di
    pop dx
    pop cx
    pop bx
    ret

DrawFlower:
    push bx
    push cx
    push dx
    push di
    mov bx,FlowerSpriteOrange
    mov cx,7            ; 7 rows
dfRow:
    cmp cx,0
    je dfDone
    push di
    mov dx,7            ; 7 columns
dfCol:
    cmp dx,0
    je dfNext
    mov al,[bx]
    mov [es:di],al
    inc bx
    inc di
    dec dx
    jmp dfCol
dfNext:
    pop di
    add di,320
    dec cx
    jmp dfRow
dfDone:
    pop di
    pop dx
    pop cx
    pop bx
    ret

DrawRock:
    push bx
    push cx
    push dx
    push di
    mov bx,RockSprite
    mov cx,4            ; 4 rows
drRow:
    cmp cx,0
    je drDone
    push di
    mov dx,6            ; 6 columns
drCol:
    cmp dx,0
    je drNext
    mov al,[bx]
    mov [es:di],al
    inc bx
    inc di
    dec dx
    jmp drCol
drNext:
    pop di
    add di,320
    dec cx
    jmp drRow
drDone:
    pop di
    pop dx
    pop cx
    pop bx
    ret

; ============ ROAD STRIPES (ANIMATED) ============

DrawStripes:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Update stripe animation offset
    mov al, [stripeOffset]
    inc al
    cmp al, 28
    jb noResetStripe
    xor al, al
noResetStripe:
    mov [stripeOffset], al
    
    mov cx, 200
    xor di, di
    add di, 80          ; Start at left edge of road
    
stripeLoop1:
    cmp cx, 0
    jne stripeContinue
    jmp stripeExit
stripeContinue:
    push cx
    
    ; Calculate if this row should have stripes
    mov ax, 200
    sub ax, cx
    add al, [stripeOffset]
    mov bl, 14
    div bl
    test al, 1
    jz noStripeRow
    
    ; Draw white stripes (4 pixels wide each) - NOW ONLY 2 STRIPES FOR 3 LANES
    mov ax, 58          ; First stripe moved more to center
    add ax, di
    push di
    mov di, ax
    mov byte [es:di], 15
    mov byte [es:di+1], 15
    mov byte [es:di+2], 15
    mov byte [es:di+3], 15
    pop di
    
    mov ax, 98          ; Second stripe moved more to center
    add ax, di
    push di
    mov di, ax
    mov byte [es:di], 15
    mov byte [es:di+1], 15
    mov byte [es:di+2], 15
    mov byte [es:di+3], 15
    pop di
    jmp doneStripeRow
    
noStripeRow:
    ; Draw road color (grey) - NOW ONLY 2 STRIPES FOR 3 LANES
    mov ax, 58          ; First stripe moved more to center
    add ax, di
    push di
    mov di, ax
    mov byte [es:di], 8
    mov byte [es:di+1], 8
    mov byte [es:di+2], 8
    mov byte [es:di+3], 8
    pop di
    
    mov ax, 98          ; Second stripe moved more to center
    add ax, di
    push di
    mov di, ax
    mov byte [es:di], 8
    mov byte [es:di+1], 8
    mov byte [es:di+2], 8
    mov byte [es:di+3], 8
    pop di
    
doneStripeRow:
    add di, 320
    pop cx
    dec cx
    jmp stripeLoop1
    
stripeExit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ PLAYER CAR FUNCTIONS ============

LoadCar:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Calculate screen position (Y * 320 + X)
    mov ax, [playerY]
    mov bx, 320
    mul bx
    add ax, [playerX]
    mov di, ax
    
    mov bx, CarModel
    mov cx, 14          ; 14 rows
lcRow:
    cmp cx, 0
    je lcExit
    push di
    mov dx, 12          ; 12 columns
lcCol:
    cmp dx, 0
    je lcDone
    mov al, [bx]
    cmp al, 255         ; Skip transparent pixels
    je lcSkip
    mov [es:di], al
lcSkip:
    inc bx
    inc di
    dec dx
    jmp lcCol
lcDone:
    pop di
    add di, 320
    dec cx
    jmp lcRow
lcExit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

EraseCar:
    push ax
    push cx
    push dx
    push di
    
    ; Calculate screen position
    mov ax, [playerY]
    mov bx, 320
    mul bx
    add ax, [playerX]
    mov di, ax
    
    mov cx, 14          ; 14 rows
ecRow:
    cmp cx, 0
    je ecExit
    push di
    mov dx, 12          ; 12 columns
ecCol:
    cmp dx, 0
    je ecDone
    mov byte [es:di], 8 ; Draw road color
    inc di
    dec dx
    jmp ecCol
ecDone:
    pop di
    add di, 320
    dec cx
    jmp ecRow
ecExit:
    pop di
    pop dx
    pop cx
    pop ax
    ret


; ============ FIXED INPUT HANDLING - ESC DETECTION ============

HandleInput:
    push ax
    push bx
    
    ; Check if key is pressed
    mov ah, 1
    int 16h
    jnz hiKeyPressed
    jmp hiNoKey
    
hiKeyPressed:
    ; Get key - ah = scan code, al = ASCII
    mov ah, 0
    int 16h
    
    ; Save scan code for extended keys
    mov bh, ah          ; BH = scan code
    
    ; Check game state
    mov bl, [gameState]
    cmp bl, 0
    jne hiInGame
    jmp hiStartScreen
    
hiInGame:
    ; In-game controls - check scan codes for arrow keys
    cmp bh, 4Bh         ; Left arrow scan code
    je hiMoveLeft
    cmp bh, 4Dh         ; Right arrow scan code
    je hiMoveRight
    
    ; Check ESC - ASCII value 27
    cmp al, 27
    je hiExit
    
    jmp hiNoKey
    
hiStartScreen:
    ; Any key starts the game
    mov byte [gameState], 1
    call InitialSetup   ; Initialize game screen
    jmp hiNoKey
    
hiMoveLeft:
    call EraseCar
    mov ax, [playerX]
    cmp ax, PLAYER_MIN_X ; Left boundary
    jbe hiNoKey
    sub word [playerX], 8  ; Fixed: Use original value 8
    call LoadCar
    jmp hiNoKey
    
hiMoveRight:
    call EraseCar
    mov ax, [playerX]
    cmp ax, PLAYER_MAX_X ; Right boundary
    jae hiNoKey
    add word [playerX], 8  ; Fixed: Use original value 8
    call LoadCar
    jmp hiNoKey
    
hiExit:
    ; ESC pressed - go to pause screen
    call HandlePause
    jmp hiNoKey
    
hiNoKey:
    pop bx
    pop ax
    ret




; ============ GENERIC SPRITE ERASER ============
; BX = width, CX = height, DI = offset

EraseSprite:
    push ax
    push cx
    push dx
    push di
    
esRow:
    cmp cx, 0
    je esExit
    push di
    mov dx, bx
esCol:
    cmp dx, 0
    je esDone
    mov byte [es:di], 8 ; Draw road color
    inc di
    dec dx
    jmp esCol
esDone:
    pop di
    add di, 320
    dec cx
    jmp esRow
esExit:
    pop di
    pop dx
    pop cx
    pop ax
    ret

; ============ CALCULATE SCREEN OFFSET ============
; AX = Y, SI = X, returns DI = screen offset

CalcOffset:
    push bx
    push dx
    mov bx, 320
    mul bx
    add ax, si
    mov di, ax
    pop dx
    pop bx
    ret

; ============ ENEMY FUNCTIONS ============

DrawEnemy:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov bx, CarModelObstacle
    mov cx, 14          ; 14 rows
deRow:
    cmp cx, 0
    je deExit
    push di
    mov dx, 12          ; 12 columns
deCol:
    cmp dx, 0
    je deDone
    mov al, [bx]
    cmp al, 255         ; Skip transparent pixels
    je deSkip
    mov [es:di], al
deSkip:
    inc bx
    inc di
    dec dx
    jmp deCol
deDone:
    pop di
    add di, 320
    dec cx
    jmp deRow
deExit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

UpdateEnemies:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    xor bx, bx
    
ueLoop:
    cmp bx, MAX_ENEMIES
    jb ueContinue
    jmp ueExit
ueContinue:
    mov al, [enemyActive + bx]
    cmp al, 0
    je ueNext
    
    ; Get current position
    push bx
    shl bx, 1
    mov si, [enemyX + bx]
    mov ax, [enemyY + bx]
    pop bx
    
    ; Erase at old position
    push bx
    push ax
    push si
    call CalcOffset
    mov bx, 12
    mov cx, 14
    call EraseSprite
    pop si
    pop ax
    pop bx
    
    ; Move down based on speed setting
    mov cl, GAME_SPEED
    add ax, cx          ; Use game speed value
    cmp ax, 186         ; Check if off screen (FIXED: Use original value)
    jb ueOnScreen
    mov byte [enemyActive + bx], 0
    jmp ueNext
    
ueOnScreen:
    ; Save new Y position
    push bx
    shl bx, 1
    mov [enemyY + bx], ax
    pop bx
    
    ; Draw at new position
    push bx
    shl bx, 1
    mov ax, [enemyY + bx]
    pop bx
    call CalcOffset
    call DrawEnemy
    
ueNext:
    inc bx
    jmp ueLoop
    
ueExit:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ COIN FUNCTIONS ============

DrawCoin:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov bx, CoinModel
    mov cx, 5           ; 5 rows
dcRow:
    cmp cx, 0
    je dcExit
    push di
    mov dx, 5           ; 5 columns
dcCol:
    cmp dx, 0
    je dcDone
    mov al, [bx]
    mov [es:di], al
    inc bx
    inc di
    dec dx
    jmp dcCol
dcDone:
    pop di
    add di, 320
    dec cx
    jmp dcRow
dcExit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

UpdateCoins:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    xor bx, bx
    
ucLoop:
    cmp bx, MAX_COINS
    jb ucContinue
    jmp ucExit
ucContinue:
    mov al, [coinActive + bx]
    cmp al, 0
    je ucNext
    
    ; Get current position
    push bx
    shl bx, 1
    mov si, [coinX + bx]
    mov ax, [coinY + bx]
    pop bx
    
    ; Erase at old position
    push bx
    push ax
    push si
    call CalcOffset
    mov bx, 5
    mov cx, 5
    call EraseSprite
    pop si
    pop ax
    pop bx
    
    ; Move down based on speed setting
    mov cl, GAME_SPEED
    add ax, cx          ; Use game speed value
    cmp ax, 195         ; Check if off screen (FIXED: Use original value)
    jb ucOnScreen
    mov byte [coinActive + bx], 0
    jmp ucNext
    
ucOnScreen:
    ; Save new Y position
    push bx
    shl bx, 1
    mov [coinY + bx], ax
    pop bx
    
    ; Draw at new position
    push bx
    shl bx, 1
    mov ax, [coinY + bx]
    pop bx
    call CalcOffset
    call DrawCoin
    
ucNext:
    inc bx
    jmp ucLoop
    
ucExit:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ FUEL FUNCTIONS ============

DrawFuel:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov bx, FuelModel
    mov cx, 10          ; 10 rows
dflRow:
    cmp cx, 0
    je dflExit
    push di
    mov dx, 10          ; 10 columns
dflCol:
    cmp dx, 0
    je dflDone
    mov al, [bx]
    mov [es:di], al
    inc bx
    inc di
    dec dx
    jmp dflCol
dflDone:
    pop di
    add di, 320
    dec cx
    jmp dflRow
dflExit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

UpdateFuel:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    xor bx, bx
    
ufLoop:
    cmp bx, MAX_FUEL
    jb ufContinue
    jmp ufExit
ufContinue:
    mov al, [fuelActive + bx]
    cmp al, 0
    je ufNext
    
    ; Get current position
    push bx
    shl bx, 1
    mov si, [fuelX + bx]
    mov ax, [fuelY + bx]
    pop bx
    
    ; Erase at old position
    push bx
    push ax
    push si
    call CalcOffset
    mov bx, 10
    mov cx, 10
    call EraseSprite
    pop si
    pop ax
    pop bx
    
    ; Move down based on speed setting
    mov cl, GAME_SPEED
    add ax, cx          ; Use game speed value
    cmp ax, 190         ; Check if off screen (FIXED: Use original value)
    jb ufOnScreen
    mov byte [fuelActive + bx], 0
    jmp ufNext
    
ufOnScreen:
    ; Save new Y position
    push bx
    shl bx, 1
    mov [fuelY + bx], ax
    pop bx
    
    ; Draw at new position
    push bx
    shl bx, 1
    mov ax, [fuelY + bx]
    pop bx
    call CalcOffset
    call DrawFuel
    
ufNext:
    inc bx
    jmp ufLoop
    
ufExit:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ SPAWNER FUNCTIONS (3 LANES) ============

SpawnEnemyTicker:
    push ax
    push bx
    push cx
    push dx
    
    ; Check spawn timer
    mov al, [spawnTimer]
    cmp al, 0
    jne seWait
    
    ; Find free enemy slot
    xor bx, bx
seFindFree:
    cmp bx, MAX_ENEMIES
    jae seDone
    mov al, [enemyActive + bx]
    cmp al, 0
    je seFoundFree
    inc bx
    jmp seFindFree
    
seFoundFree:
    ; Get random lane (0-2) - now only 3 lanes
    mov ah, 0
    int 0x1A            ; Get system timer
    mov ax, dx
    xor dx, dx
    mov cx, 3           ; Only 3 lanes now
    div cx              ; DX = remainder (0, 1, or 2)
    
    cmp dx, 0
    je seLane1
    cmp dx, 1
    je seLane2
    jmp seLane3
    
seLane1:
    mov cx, lane1X
    jmp seSetPos
seLane2:
    mov cx, lane2X
    jmp seSetPos
seLane3:
    mov cx, lane3X
    
seSetPos:
    ; Set enemy position
    push bx
    shl bx, 1
    mov [enemyX + bx], cx
    mov word [enemyY + bx], 0
    pop bx
    mov byte [enemyActive + bx], 1
    mov byte [spawnTimer], ENEMY_SPAWN_RATE ; Reset timer using configurable rate
    jmp seDone
    
seWait:
    dec byte [spawnTimer]
    
seDone:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

SpawnCoinTicker:
    push ax
    push bx
    push cx
    push dx
    
    ; Check spawn timer
    mov al, [spawnCoinTimer]
    cmp al, 0
    jne scWait
    
    ; Find free coin slot
    xor bx, bx
scFindFree:
    cmp bx, MAX_COINS
    jae scDone
    mov al, [coinActive + bx]
    cmp al, 0
    je scFoundFree
    inc bx
    jmp scFindFree
    
scFoundFree:
    ; Get random lane (0-2) - now only 3 lanes
    mov ah, 0
    int 0x1A            ; Get system timer
    mov ax, dx
    xor dx, dx
    mov cx, 3           ; Only 3 lanes now
    div cx
    
    cmp dx, 0
    je scLane1
    cmp dx, 1
    je scLane2
    jmp scLane3
    
scLane1:
    mov cx, lane1X
    jmp scSetPos
scLane2:
    mov cx, lane2X
    jmp scSetPos
scLane3:
    mov cx, lane3X
    
scSetPos:
    ; Set coin position
    push bx
    shl bx, 1
    mov [coinX + bx], cx
    mov word [coinY + bx], 0
    pop bx
    mov byte [coinActive + bx], 1
    mov byte [spawnCoinTimer], COIN_SPAWN_RATE ; Reset timer using configurable rate
    jmp scDone
    
scWait:
    dec byte [spawnCoinTimer]
    
scDone:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

SpawnFuelTicker:
    push ax
    push bx
    push cx
    push dx
    
    ; Check spawn timer
    mov al, [spawnFuelTimer]
    cmp al, 0
    jne sfWait
    
    ; Find free fuel slot
    xor bx, bx
sfFindFree:
    cmp bx, MAX_FUEL
    jae sfDone
    mov al, [fuelActive + bx]
    cmp al, 0
    je sfFoundFree
    inc bx
    jmp sfFindFree
    
sfFoundFree:
    ; Get random lane (0-2) - now only 3 lanes
    mov ah, 0
    int 0x1A            ; Get system timer
    mov ax, dx
    xor dx, dx
    mov cx, 3           ; Only 3 lanes now
    div cx
    
    cmp dx, 0
    je sfLane1
    cmp dx, 1
    je sfLane2
    jmp sfLane3
    
sfLane1:
    mov cx, lane1X
    jmp sfSetPos
sfLane2:
    mov cx, lane2X
    jmp sfSetPos
sfLane3:
    mov cx, lane3X
    
sfSetPos:
    ; Set fuel position
    push bx
    shl bx, 1
    mov [fuelX + bx], cx
    mov word [fuelY + bx], 0
    pop bx
    mov byte [fuelActive + bx], 1
    mov byte [spawnFuelTimer], FUEL_SPAWN_RATE ; Reset timer using configurable rate
    jmp sfDone
    
sfWait:
    dec byte [spawnFuelTimer]
    
sfDone:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ VSYNC WAIT ============

WaitVSync:
    push ax
    push dx
    mov dx, 0x03DA      ; VGA status register
wvWait1:
    in al, dx
    test al, 8          ; Test vertical retrace bit
    jz wvWait1
wvWait2:
    in al, dx
    test al, 8
    jnz wvWait2
    pop dx
    pop ax
    ret



; ============ PAUSE AND ESC HANDLING ============

HandlePause:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Draw pause screen overlay
    call DrawPauseScreen
    
.pauseLoop:
    call WaitVSync
    
    ; Check for key press
    mov ah, 1
    int 16h
    jz .pauseLoop            ; No key pressed, continue waiting
    
    ; Get key
    mov ah, 0
    int 16h
    
       ; Check if 'Y' or 'y' was pressed (end game)
    cmp al, 'y'
    je .doEndGame
    cmp al, 'Y'
    je .doEndGame
    
    ; Check if 'N' or 'n' was pressed (resume game)
    cmp al, 'n'
    je .resumeGame
    cmp al, 'N'
    je .resumeGame
    
    ; Check if ESC was pressed (resume game)
    cmp al, 27
    je .resumeGame
    
    ; Invalid key, wait again
    jmp .pauseLoop
    
.doEndGame:
    ; Set game state to end screen
    mov byte [gameState], 3    ; State 3 = end screen
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    ; Check if 'N' or 'n' was pressed (resume game)
    cmp al, 'n'
    je .resumeGame
    cmp al, 'N'
    je .resumeGame
    
    ; Check if ESC was pressed (resume game)
    cmp al, 27
    je .resumeGame
    
    ; Invalid key, wait again
    jmp .pauseLoop
    
.resumeGame:
    ; Clear the pause screen area by redrawing the background
    ; We need to clear a larger area to ensure everything is erased
    
    ; First, clear the entire pause area (80x160 rectangle)
    mov di, 320 * 60 + 80    ; Top-left corner of pause box
    mov cx, 81              ; 80 rows
    
.clearPauseArea:
    push di
    push cx
    mov cx, 160              ; 160 columns
    
.clearPauseCol:
    ; We need to restore the original background, not just road color
    ; Check if this pixel is in road area or grass area
    mov ax, di
    xor dx, dx
    mov bx, 320
    div bx                   ; AX = row, DX = column
    
    ; Check if column is in road area (80-240)
    cmp dx, 80
    jb .drawGrass
    cmp dx, 240
    jae .drawGrass
    
    ; It's road area
    mov byte [es:di], 8      ; Road color
    jmp .continueClear
    
.drawGrass:
    ; It's grass area - draw alternating green stripes
    mov ax, di
    xor dx, dx
    mov bx, 320
    div bx                   ; AX = row
    
    ; Determine stripe pattern
    mov bx, ax               ; Row number
    mov ax, bx
    mov bl, 5
    div bl
    test al, 1
    jz .grassLight
    mov byte [es:di], 2      ; Dark green
    jmp .continueClear
.grassLight:
    mov byte [es:di], 10     ; Light green
    
.continueClear:
    inc di
    loop .clearPauseCol
    
    pop cx
    pop di
    add di, 320
    loop .clearPauseArea
    
    ; Now we need to redraw the road stripes that were in this area
    ; Call DrawStripes to redraw the animated stripes
    call DrawStripes
    
    ; Redraw grass sprites that might be in this area
    call RedrawGrassInPauseArea
    
    ; Now redraw all game elements
    call LoadCar
    
    ; Redraw all active enemies
    push bx
    xor bx, bx
.redrawEnemies:
    cmp bx, MAX_ENEMIES
    jae .redrawCoins
    mov al, [enemyActive + bx]
    cmp al, 0
    je .skipEnemy
    
    ; Draw this enemy
    push bx
    shl bx, 1
    mov ax, [enemyY + bx]
    mov si, [enemyX + bx]
    pop bx
    push bx
    push ax
    push si
    call CalcOffset
    call DrawEnemy
    pop si
    pop ax
    pop bx
    
.skipEnemy:
    inc bx
    jmp .redrawEnemies
    
.redrawCoins:
    ; Redraw all active coins
    xor bx, bx
.redrawCoinsLoop:
    cmp bx, MAX_COINS
    jae .redrawFuel
    mov al, [coinActive + bx]
    cmp al, 0
    je .skipCoin
    
    ; Draw this coin
    push bx
    shl bx, 1
    mov ax, [coinY + bx]
    mov si, [coinX + bx]
    pop bx
    push bx
    push ax
    push si
    call CalcOffset
    call DrawCoin
    pop si
    pop ax
    pop bx
    
.skipCoin:
    inc bx
    jmp .redrawCoinsLoop
    
.redrawFuel:
    ; Redraw all active fuel cans
    xor bx, bx
.redrawFuelLoop:
    cmp bx, MAX_FUEL
    jae .redrawUI
    mov al, [fuelActive + bx]
    cmp al, 0
    je .skipFuel
    
    ; Draw this fuel can
    push bx
    shl bx, 1
    mov ax, [fuelY + bx]
    mov si, [fuelX + bx]
    pop bx
    push bx
    push ax
    push si
    call CalcOffset
    call DrawFuel
    pop si
    pop ax
    pop bx
    
.skipFuel:
    inc bx
    jmp .redrawFuelLoop
    
.redrawUI:
    ; Redraw UI elements
    call DrawScore
    call DrawFuelBar
    pop bx
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
.endGame:
    ; Set game state to end screen
    mov byte [gameState], 3    ; State 3 = end screen
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ CLEAR PAUSE OVERLAY ============

ClearPauseOverlay:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Clear the pause box area (80 rows x 160 columns)
    ; This area was at position (80, 60) to (240, 140)
    mov di, 320 * 60 + 80
    mov cx, 80              ; 80 rows
    
.clearRow:
    push di
    push cx
    mov cx, 160             ; 160 columns
    
.clearCol:
    ; Determine if this pixel is road or grass
    mov ax, di
    xor dx, dx
    mov bx, 320
    div bx                  ; AX = row, DX = column
    
    ; Check if column is in road area (80-240)
    cmp dx, 80
    jb .grassPixel
    cmp dx, 240
    jae .grassPixel
    
    ; Road pixel
    mov byte [es:di], 8     ; Road color
    jmp .nextPixel
    
.grassPixel:
    ; Grass pixel - draw alternating green
    mov bx, ax              ; Row number
    mov ax, bx
    mov bl, 5
    div bl
    test al, 1
    jz .grassLight
    mov byte [es:di], 2     ; Dark green
    jmp .nextPixel
.grassLight:
    mov byte [es:di], 10    ; Light green
    
.nextPixel:
    inc di
    loop .clearCol
    
    pop cx
    pop di
    add di, 320
    loop .clearRow
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW PAUSE SCREEN ============

DrawPauseScreen:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Draw semi-transparent overlay (dark overlay by drawing darker colors)
    ; Draw black rectangle in center (160x80 area, centered at 160,100)
    mov di, 320 * 60 + 80
    mov cx, 80              ; 80 rows
    
.overlayRow:
    push di
    mov dx, 160             ; 160 columns (dark overlay)
    
.overlayCol:
    mov byte [es:di], 0     ; Black color
    inc di
    dec dx
    jnz .overlayCol
    
    pop di
    add di, 320
    loop .overlayRow
    
    ; Draw white border around pause box
    mov di, 320 * 60 + 80
    mov cx, 160
.topBorder:
    mov byte [es:di], 15    ; White
    inc di
    loop .topBorder
    
    mov di, 320 * 140 + 80
    mov cx, 160
.bottomBorder:
    mov byte [es:di], 15    ; White
    inc di
    loop .bottomBorder
    
    mov di, 320 * 60 + 80
    mov cx, 80
.leftBorder:
    mov byte [es:di], 15
    add di, 320
    loop .leftBorder
    
    mov di, 320 * 60 + 239
    mov cx, 80
.rightBorder:
    mov byte [es:di], 15
    add di, 320
    loop .rightBorder
    
    ; Draw "PAUSED" text (centered in box)
    mov di, 320 * 75 + 125
    mov bx, pausedText
    mov al, 15              ; White
    call DrawText
    
    ; Draw "End Game? Y/N" text
    mov di, 320 * 95 + 105
    mov bx, pausePromptText
    mov al, 15              ; White
    call DrawText
    
    ; Draw "Press ESC to Resume" text
    mov di, 320 * 110 + 85
    mov bx, resumeText
    mov al, 14              ; Yellow
    call DrawText
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


; ============ END GAME SCREEN ============

DrawEndScreen:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    ; Fill screen with dark blue background
    xor di, di
    mov cx, 64000           ; 320 * 200 pixels
    mov al, 1               ; Dark blue color
    
.fillLoop:
    mov [es:di], al
    inc di
    loop .fillLoop
    
    ; Draw "GAME OVER!" at top (Y=30, centered)
    mov di, 320 * 30 + 110
    mov bx, gameOverText
    mov al, 12              ; Red color
    call DrawText
    
    ; Draw final score label (Y=80)
    mov di, 320 * 80 + 100
    mov bx, finalScoreLabel
    mov al, 15              ; White
    call DrawText
    
    ; Draw actual score value (Y=100, centered)
    mov ax, [score]
    mov di, 320 * 100 + 155
    call DrawLargeNumber    ; Draw in larger format
    
    ; Draw final fuel label (Y=130)
    mov di, 320 * 130 + 105
    mov bx, finalFuelLabel
    mov al, 15              ; White
    call DrawText
    
    ; Draw actual fuel value (Y=150)
    mov ax, [fuel]
    mov di, 320 * 150 + 155
    call DrawLargeNumber
    
    ; Draw exit prompt (Y=180)
    mov di, 320 * 180 + 80
    mov bx, exitPromptText
    mov al, 14              ; Yellow
    call DrawText
    
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ DRAW LARGE NUMBER (FOR END SCREEN) ============

DrawLargeNumber:
    ; Draw number in AX at DI position in larger format (2x scale)
    ; AX = number to draw, DI = screen offset
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov si, 10
    xor cx, cx              ; Digit counter
    mov bx, 15              ; White color
    
.divLoop:
    xor dx, dx
    div si                  ; AX = AX / 10, DX = remainder (digit)
    push dx                 ; Save digit
    inc cx
    cmp ax, 0
    jne .divLoop
    
    ; Store original DI for drawing
    mov si, di
    
.drawLoop:
    pop ax
    add al, '0'             ; Convert to ASCII
    push cx
    push di
    
    ; Draw character twice horizontally and vertically for larger size
    mov bl, al              ; Save character
    
    ; First pass - normal
    call DrawChar
    
    ; Move back and draw again offset by 1 pixel right
    pop di
    push di
    inc di
    mov al, bl
    call DrawChar
    
    pop di
    pop cx
    add di, 12              ; Move 12 pixels right for next large digit (6*2)
    loop .drawLoop
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============ END GAME STATE HANDLER ============

HandleEndScreen:
    ; Wait for any key to return to start screen
.endScreenLoop:
    call WaitVSync
    
    ; Check for key press
    mov ah, 1
    int 16h
    jz .endScreenLoop        ; No key pressed, continue waiting
    
    ; Get key to clear buffer
    mov ah, 0
    int 16h
    
    ; Return to start screen
    ret



; ============ RESET GAME STATE ============
; Call this when returning to start screen to clear all active objects

ResetGameState:
    push ax
    push bx
    
    ; Clear all enemy active flags
    xor bx, bx
.clearEnemies:
    cmp bx, MAX_ENEMIES
    jae .clearCoins
    mov byte [enemyActive + bx], 0
    inc bx
    jmp .clearEnemies
    
.clearCoins:
    ; Clear all coin active flags
    xor bx, bx
.clearCoinsLoop:
    cmp bx, MAX_COINS
    jae .clearFuel
    mov byte [coinActive + bx], 0
    inc bx
    jmp .clearCoinsLoop
    
.clearFuel:
    ; Clear all fuel active flags
    xor bx, bx
.clearFuelLoop:
    cmp bx, MAX_FUEL
    jae .done
    mov byte [fuelActive + bx], 0
    inc bx
    jmp .clearFuelLoop
    
.done:
    pop bx
    pop ax
    ret



; ============ MAIN PROGRAM ============

start:
    ; Set VGA mode 13h
    mov ax, 0x13
    int 0x10
    mov ax, 0xA000
    mov es, ax
    
    ; Draw start screen
    call DrawStartScreen
    
    ; Wait for keypress to start
StartScreenLoop:
    call WaitVSync
    call HandleInput
    mov al, [gameState]
    cmp al, 0
    je StartScreenLoop

; Main game loop
MainLoop:
    call WaitVSync
    call HandleInput
    
    ; Check game state
    mov al, [gameState]
    cmp al, 1           ; Only continue if state is 1 (playing)
    jne .checkEndStates
    
    ; Update game every 2 frames
    inc byte [frameCounter]
    mov al, [frameCounter]
    cmp al, 2
    jb .skipUpdate
    mov byte [frameCounter], 0
    
    ; Update all game elements
    call DrawStripes
    call SpawnEnemyTicker
    call SpawnCoinTicker
    call SpawnFuelTicker
    call UpdateEnemies
    call UpdateCoins
    call UpdateFuel
    call LoadCar
    
    ; Check collisions
    call CheckEnemyCollision
    call CheckCoinCollision
    call CheckFuelCollision
    
    ; Draw UI
    call DrawScore
    call DrawFuelBar
    call DecreaseFuel
    
.skipUpdate:
    jmp MainLoop

.checkEndStates:
    ; Check if game over (state 2)
    cmp al, 2
    je .gameOver
    
    ; Check if from pause menu (state 3)
    cmp al, 3
    je .gameOver
    
    ; Otherwise loop back to start screen
    jmp StartScreenLoop

.gameOver:
    ; Reset all active game objects
    call ResetGameState
    
    ; Clear timers and frame counter
    xor al, al
    mov [spawnTimer], al
    mov [spawnCoinTimer], al
    mov [spawnFuelTimer], al
    mov [frameCounter], al
    
    ; Draw end screen with final score
    call DrawEndScreen
    call HandleEndScreen
    
    ; Reset game state and return to start screen
    mov byte [gameState], 0
    mov word [score], 0
    mov word [fuel], INITIAL_FUEL ; Use configurable initial fuel
    
    ; Reset player position
    mov word [playerX], 154
    mov word [playerY], 170
    
    ; Set VGA mode back to 13h
    mov ax, 0x13
    int 0x10
    mov ax, 0xA000
    mov es, ax
    
    ; Draw start screen
    call DrawStartScreen
    
    jmp StartScreenLoop
	
	; ============ PROGRAM EXIT ============

ExitToDOS:
    ; Restore text mode (mode 3)
    mov ax, 0x0003
    int 0x10
    
    ; Terminate program
    mov ax, 0x4C00
    int 0x21
