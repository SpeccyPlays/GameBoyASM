INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

jp EntryPoint

ds $150 - @, 0;Making room for the header

EntryPoint:
	;Do not turn the LCD off outside of VBlank
WaitVBlank:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank

	;turn LCD off
	ld a, 0
	ld [rLCDC], a

	;copy the tile data
	ld de, Tiles
	ld hl, $9000
	ld bc, TilesEnd - Tiles
	call Memcopy

	;copy the tilemap
	ld de, Tilemap
	ld hl, $9800
	ld bc, TilemapEnd - Tilemap
	call Memcopy

	;Copy the paddle data
	ld de, Paddle
	ld hl, $8000
	ld bc, PaddleEnd - Paddle
	call Memcopy

	;copy the ball title
	ld de, Ball
	ld hl, $8010
	ld bc, BallEnd - Ball
	call Memcopy
	
	ld a, 0
	ld b, 160
	ld hl, _OAMRAM
ClearOam:
	ld [hli], a 
	dec b 
	jp nz, ClearOam

	;Initialise paddle sprite in OAM
	ld hl, _OAMRAM
	ld a, 128 + 16
	ld [hli], a 
	ld a, 16 + 8
	ld [hli], a 
	ld a, 0
	ld [hli], a 
	ld [hli], a

	;Initialise the ball sprite
	ld a, 100 + 16
	ld [hli], a 
	ld a, 32 + 8
	ld [hli], a 
	ld a, 1
	ld [hli], a 
	ld a, 0
	ld [hli], a

	;Ball goes up and to the right to start
	ld a, 1
	ld [wBallMomentumX], a 
	ld a, -1
	ld [wBallMomentumY], a 

	;turn the lcd on
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
	ld [rLCDC], a 

	;Initiate LCD registers on first blank frame
	ld a, %1100100
	ld [rBGP], a 
	ld a, %11100100
	ld [rOBP0], a

	;initialise global vars
	ld a, 0
	ld [wFrameCounter], a
	ld [wCurKeys], a
	ld [wNewKeys], a

Main :
	; wait until it's not VBlank
	ld a, [rLY]
	cp 144
	jp nc, Main
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2

	;add momentum to it's position in OAM
	ld a, [wBallMomentumX]
	ld b, a 
	ld a, [_OAMRAM + 5]
	add a, b
	ld [_OAMRAM + 5], a 

	ld a, [wBallMomentumY]
	ld b, a 
	ld a, [_OAMRAM + 4]
	add a, b 
	ld [_OAMRAM + 4], a

	;check the current keys every frame and move left or right.
	call UpdateKeys

BounceOnTop:
	; Remember to offset the OAM position!
	; (8, 16) in OAM coordinates is (0, 0) on the screen.
	ld a, [_OAMRAM + 4]
	sub a, 16 + 1
	ld c, a
	ld a, [_OAMRAM + 5]
	sub a, 8
	ld b, a
	call GetTileByPixel ; Returns tile address in hl
	ld a, [hl]
	call IsWallTile
	jp nz, BounceOnRight
	ld a, 1
	ld [wBallMomentumY], a
	
BounceOnRight:
	ld a, [_OAMRAM + 4]
	sub a, 16
	ld c, a
	ld a, [_OAMRAM + 5]
	sub a, 8 - 1
	ld b, a
	call GetTileByPixel
	ld a, [hl]
	call IsWallTile
	jp nz, BounceOnLeft
	ld a, -1
	ld [wBallMomentumX], a

BounceOnLeft:
	ld a, [_OAMRAM + 4]
	sub a, 16
	ld c, a
	ld a, [_OAMRAM + 5]
	sub a, 8 + 1
	ld b, a
	call GetTileByPixel
	ld a, [hl]
	call IsWallTile
	jp nz, BounceOnBottom
	ld a, 1
	ld [wBallMomentumX], a

BounceOnBottom:
	ld a, [_OAMRAM + 4]
	sub a, 16 - 1
	ld c, a
	ld a, [_OAMRAM + 5]
	sub a, 8
	ld b, a
	call GetTileByPixel
	ld a, [hl]
	call IsWallTile
	jp nz, BounceDone
	ld a, -1
	ld [wBallMomentumY], a
BounceDone:

    
	; First, check if the ball is low enough to bounce off the paddle.
	ld a, [_OAMRAM]
	ld b, a
	ld a, [_OAMRAM + 4]
	add a, 6
	cp a, b
	jp nz, PaddleBounceDone ; If the ball isn't at the same Y position as the paddle, it can't bounce.
	; Now let's compare the X positions of the objects to see if they're touching.
	ld a, [_OAMRAM + 5] ; Ball's X position.
	ld b, a
	ld a, [_OAMRAM + 1] ; Paddle's X position.
	sub a, 8
	cp a, b
	jp nc, PaddleBounceDone
	add a, 8 + 16 ; 8 to undo, 16 as the width.
	cp a, b
	jp c, PaddleBounceDone

	ld a, -1
	ld [wBallMomentumY], a

PaddleBounceDone:

	;Check left button first
CheckLeft:
	ld a, [wCurKeys]
	and a, PADF_LEFT
	jp z, CheckRight
Left:
	;move one pixel left
	ld a, [_OAMRAM + 1]
	dec a 
	;Don't move if at edge
	cp a, 15
	jp z, Main
	ld [_OAMRAM + 1], a
	jp Main
CheckRight:
	ld a, [wCurKeys]
	and a, PADF_RIGHT
	jp z, Main

Right:
	;move th paddle one pixel to the right
	ld a, [_OAMRAM + 1]
	inc a
	;don't move if at edge
	cp a, 105
	jp z, Main
	ld [_OAMRAM + 1], a 
	jp Main
;copy bytes from one area to anothr
;@param de: source
;@param hl: Destination
;@param bc: Length
Memcopy:
	ld a, [de]
	ld [hli], a
	inc de 
	dec bc
	ld a, b 
	or a, c 
	jp nz, Memcopy
	ret

UpdateKeys:
 	;Poll half the controller
 	ld a, P1F_GET_BTN
 	call .onenibble
 	ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

 	;Poll the other half
 	ld a, P1F_GET_DPAD
 	call .onenibble
 	swap a ; A3-0 = unpressed directions; A7-4 = 1
 	xor a, b ; A = pressed buttons + directions
 	ld b, a ; B = pressed buttons + directions

 	;And release the controller
 	ld a, P1F_GET_NONE
 	ldh [rP1], a

 	;Combine with previous wCurKeys to make wNewKeys
 	ld a, [wCurKeys]
 	xor a, b ; A = keys that changed state
 	and a, b ; A = keys that changed to pressed
 	ld [wNewKeys], a
 	ld a, b
 	ld [wCurKeys], a
 	ret

.onenibble
 	ldh [rP1], a ; switch the key matrix
 	call .knownret ; burn 10 cycles calling a known ret
 	ldh a, [rP1] ; ignore value while waiting for the key matrix to settle
 	ldh a, [rP1]
 	ldh a, [rP1] ; this read counts
 	or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
 	ret

;Convert a pixel position to a tilemap address
;hl = $9800 + x + y * 32
;@param b: X
;@param c: Y
;return hl: tile address
GetTileByPixel:
	;Divide by 8 to convert a pixel position to a tile position
	;then multiply the Y position by 32
	;these effectively cancel out so only need to mask the Y value
	ld a, c
	and a, %11111000
	ld l, a
	ld h, 0
	;the position * 8 is in hl
	add hl, hl ; position * 16
	add hl, hl ; position * 32
	;Convert x position to an offset
	ld a, b 
	srl a ; a / 2
	srl a ; a / 4
	srl a ; a / 8
	;add the two offsets together
	add a, l
	ld l, a 
	adc a, h
	sub a, l
	ld h, a
	; Add offset to tilemap's base address to finish
	ld bc, $9800
	add hl, bc
	ret

;@param a: tile ID
;@return z: set if a is a wall
IsWallTile:
	cp a, $00
	ret z
	cp a, $01
	ret z 
	cp a, $02
	ret z 
	cp a, $03
	ret z
	cp a, $04
	ret z 
	cp a, $05
	ret z 	 
	cp a, $06
	ret z
	cp a, $07
	ret 
Tiles:
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322222
	dw `33322222
	dw `33322222
	dw `33322211
	dw `33322211
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222333
	dw `22222333
	dw `22222333
	dw `11222333
	dw `11222333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `22222222
	dw `20000000
	dw `20111111
	dw `20111111
	dw `20111111
	dw `20111111
	dw `22222222
	dw `33333333
	dw `22222223
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222223
	dw `33333333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `11001100
	dw `11111111
	dw `11111111
	dw `21212121
	dw `22222222
	dw `22322232
	dw `23232323
	dw `33333333
	; Paste your logo here:
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222211
	dw `22222211
	dw `22222211
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `11221111
	dw `11221111
	dw `11000011
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11222222
	dw `11222222
	dw `11222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222211
	dw `22222200
	dw `22222200
	dw `22000000
	dw `22000000
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11000011
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11000022
	dw `11222222
	dw `11222222
	dw `11222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222200
	dw `22222200
	dw `22222211
	dw `22222211
	dw `22221111
	dw `22221111
	dw `22221111
	dw `11000022
	dw `00112222
	dw `00112222
	dw `11112200
	dw `11112200
	dw `11220000
	dw `11220000
	dw `11220000
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22000000
	dw `22000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11110022
	dw `11110022
	dw `11110022
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22221111
	dw `22222211
	dw `22222211
	dw `22222222
	dw `11220000
	dw `11110000
	dw `11110000
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222
	dw `00000000
	dw `00111111
	dw `00111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `11111111
	dw `22222222
	dw `11110022
	dw `11000022
	dw `11000022
	dw `00002222
	dw `00002222
	dw `00222222
	dw `00222222
	dw `22222222
TilesEnd:

Tilemap:
	db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0D, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0E, $0F, $10, $11, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $12, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $16, $17, $18, $19, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

Paddle:
    dw `13333331
    dw `30000003
    dw `13333331
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:

Ball:
	dw `00033000
	dw `00322300
	dw `03222230
	dw `03222230
	dw `00322300
	dw `00033000
	dw `00000000
	dw `00000000
BallEnd:

SECTION "Counter", WRAM0
wFrameCounter: db

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db

SECTION "Ball Data", WRAM0
wBallMomentumX: db
wBallMomentumY: db