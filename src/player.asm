INCLUDE "defines.inc"
INCLUDE "hardware.inc/hardware.inc"

SECTION "Player variables", WRAM0

; 0 = N, 1 = NE, 2 = E, 3 = SE, 4 = S, 5 = SW, 6 = W, 7 = NW
wPlayerFacing: db
wPlayerSubD: db

SECTION "Player", ROMX

PlayerInit::
    ; Load tank graphics into bank 0
    ld de, TankTiles
    ld hl, STARTOF(VRAM)
    ld bc, TankTilesEnd - TankTiles
    call Memcpy

    ; Clear shadow OAM
    ld hl, wShadowOAM
    ld c, OAM_COUNT * 4
    xor a
    rst MemsetSmall

    ; Write tank sprite to shadow OAM
    ld hl, wShadowOAM
    ; Entry 0 - left half
    ld a, 80 ; Y
    ld [hli], a
    ld a, 16 ; X
    ld [hli], a
    ld a, 0 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hli], a
    ; Entry 1 - right half
    ld a, 80 ; Y
    ld [hli], a
    ld a, 24 ; X + 8
    ld [hli], a
    ld a, 2 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hli], a

    ; set sprite palette
    ld a, %11100100
    ldh [hOBP0], a

    ; Set hOAMHigh to trigger DMA on next VBlank
    ld a, HIGH(wShadowOAM)
    ldh [hOAMHigh], a

    ; load the HUD graphics into VRAM
    ld de, HudTiles
    ld hl, $9000
    ld bc, HudTilesEnd - HudTiles
    call Memcpy

    ; init the player facing direction
    ld hl, wPlayerFacing
    xor a
    ld [hl], a

    ; init diagonal accumulator
    ld hl, wPlayerSubD
    ld [hl], a

    ret

PlayerUpdateMove::
    ldh a, [hHeldKeys]
    and PAD_UP
    jr z, .downInput
.upInput:
    call .moveForward
    jp OAMHigh

.downInput:
    ldh a, [hHeldKeys]
    and PAD_DOWN
    jp z, OAMHigh.done
    call .moveBackward
    jp OAMHigh

.moveForward:
    ld a, [wPlayerFacing]
    ; check if diagonal
    bit 0, a ; if odd is diagonal
    jr z, .updateForward
    ; it is diagonal so accumulate
    ld hl, wPlayerSubD
    ld a, [hl]
    add a, $B5
    ld [hl], a
    jp nc, OAMHigh.done ; skip move if no carry
.updateForward:
    ld a, [wPlayerFacing]
    add a, a        ; each entry is 2 bytes, so facing * 2
    ld hl, .deltaTable
    add a, l
    ld l, a
    adc a, h
    sub l
    ld h, a         ; hl now points to the dY entry for this facing

    ; store the deltas to get future position
    ld a, [hli] ; dY
    ld d, a
    ld a, [hl] ; dX
    ld e, a

    call CheckCollision
    ret nz

    ; apply movement if no collision
    ld a, [wShadowOAM + 0]
    add a, d ; apply dY
    ld [wShadowOAM + 0], a
    ld [wShadowOAM + 4], a

    ld a, [wShadowOAM + 1]
    add a, e ; apply dX
    ld [wShadowOAM + 1], a
    add a, 8
    ld [wShadowOAM + 5], a
    ret

.moveBackward:
    ld a, [wPlayerFacing]
    ; check if diagonal
    bit 0, a ; if odd is diagonal
    jr z, .updateBackward
    ; it is diagonal so accumulate
    ld hl, wPlayerSubD
    ld a, [hl]
    add a, $B5
    ld [hl], a
    jp nc, OAMHigh.done ; skip move if no carry
.updateBackward:
    ld a, [wPlayerFacing]
    add a, a
    ld hl, .deltaTable
    add a, l
    ld l, a
    adc a, h
    sub l
    ld h, a

    ; store the deltas to get future position
    ld a, [hli] ; dY - negated
    cpl
    inc a
    ld d, a
    ld a, [hl] ; dX - negated
    cpl
    inc a
    ld e, a

    call CheckCollision
    ret nz

    ; apply movement
    ld a, [wShadowOAM + 0]
    add a, d
    ld [wShadowOAM + 0], a
    ld [wShadowOAM + 4], a

    ld a, [wShadowOAM + 1]
    add a, e
    ld [wShadowOAM + 1], a
    add a, 8
    ld [wShadowOAM + 5], a
    ret

; movement directions deltas
.deltaTable:
;      dY   dX
    db -1,   0  ; 0 N
    db -1,   1  ; 1 NE
    db  0,   1  ; 2 E
    db  1,   1  ; 3 SE
    db  1,   0  ; 4 S
    db  1,  -1  ; 5 SW
    db  0,  -1  ; 6 W
    db -1,  -1  ; 7 NW

; @param d: dY
; @param e: dX
; @return z: set if a is a floor
CheckCollision:
    ; compute future screen space pos
    ld a, [wShadowOAM]
    add a, d ; add dY
    sub a, 13 ; undo OAM Y offset
    ld c, a

    ld a, [wShadowOAM + 1]
    add a, e ; add dX
    sub a, 6 ; undo OAM X offset
    ld b, a

    ; check the four corners for overlap
    push bc
    call GetTileByPixel
    ld a, [hl]
    pop bc
    call IsFloorTile ; top left
    ret nz
    ld a, b
    add a, 11
    ld b, a
    push bc
    call GetTileByPixel
    ld a, [hl]
    pop bc
    call IsFloorTile ; top right
    ret nz
    ld a, c
    add a, 11
    ld c, a
    push bc
    call GetTileByPixel
    ld a, [hl]
    pop bc
    call IsFloorTile ; bottom right
    ret nz
    ld a, b
    sub a, 11
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsFloorTile ; bottom left
    ret

PlayerUpdateRot::
    ldh a, [hHeldKeys]
    and PAD_LEFT
    jr z, .rightInput
.leftInput:
    ld hl, wPlayerFacing
    ld a, [hl]
    or a ; check if a is 0
    jr nz, .leftDec
    ld a, 7 ; wrap facing around to 7
    ld [hl], a
    jp .updateOAM
.leftDec:
    dec a
    ld [hl], a
    jp .updateOAM

.rightInput:
    ldh a, [hHeldKeys]
    and PAD_RIGHT
    jp z, OAMHigh.done
    ; have to load in since left code can't have run
    ld hl, wPlayerFacing
    ld a, [hl]
    cp a, 7 ; check if 7 to wrap to 0
    jr nz, .rightInc
    xor a ; wrap to 0
    ld [hl], a
    jp .updateOAM
.rightInc:
    inc a
    ld [hl], a

.updateOAM:
    ; get facing value in a
    ; this may be redundant
    ld hl, wPlayerFacing
    ld a, [hl]

    ld hl, .jumpTable
    add a, a ; each pointer is 2 bytes
    add a, l
    ld l, a
    adc a, h
    sub l
    ld h, a ; hl now points to the entry in the table

    ld a, [hli]
    ld h, [hl]
    ld l, a

    jp hl ; jump to the handler

.jumpTable:
    dw .north
    dw .northeast
    dw .east
    dw .southeast
    dw .south
    dw .southwest
    dw .west
    dw .northwest

.north:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 0 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 2 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hl], a
    jp OAMHigh

.northeast:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 16 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 18 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hl], a
    jp OAMHigh

.east:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 8 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 10 ; tile
    ld [hli], a
    ld a, 0 ; flags
    ld [hl], a
    jp OAMHigh

.southeast:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 16 ; tile
    ld [hli], a
    ld a, $40 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 18 ; tile
    ld [hli], a
    ld a, $40 ; flags
    ld [hl], a
    jp OAMHigh

.south:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 0 ; tile
    ld [hli], a
    ld a, $40 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 2 ; tile
    ld [hli], a
    ld a, $40 ; flags
    ld [hl], a
    jp OAMHigh

.southwest:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 18 ; tile
    ld [hli], a
    ld a, $60 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 16 ; tile
    ld [hli], a
    ld a, $60 ; flags
    ld [hl], a
    jp OAMHigh

.west:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 10 ; tile
    ld [hli], a
    ld a, $20 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 8 ; tile
    ld [hli], a
    ld a, $20 ; flags
    ld [hl], a
    jp OAMHigh

.northwest:
    ; Write tank sprite to shadow OAM
    ; Entry 0 - left half
    ld hl, wShadowOAM + 2
    ld a, 18 ; tile
    ld [hli], a
    ld a, $20 ; flags
    ld [hl], a
    ; Entry 1 - right half
    ld hl, wShadowOAM + 6
    ld a, 16 ; tile
    ld [hli], a
    ld a, $20 ; flags
    ld [hl], a
    jp OAMHigh

OAMHigh:
    ; Set hOAMHigh to trigger DMA on next VBlank
    ld a, HIGH(wShadowOAM)
    ldh [hOAMHigh], a
.done:
    ret

;; Collision handling

; Convert pixel pos to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
    ; First, need to divide by 8 to convert a pixel position to a tile position.
    ; After this we want to multiply the Y position by 32.
    ; These operations effectively cancel out so we only need to mask the Y value.
    ld a, c
    and a, %11111000
    ld l, a
    ld h, 0
    ; Now we have the position * 8 in hl
    add hl, hl ; position * 16
    add hl, hl ; position * 32
    ; Convert the X position to an offset.
    ld a, b
    srl a ; a / 2
    srl a ; a / 4
    srl a ; a / 8
    ; Add the two offsets together.
    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ; Add the offset to the tilemap's base address, and we are done!
    ld bc, $9800
    add hl, bc
    ret

; @param a: tile ID
; @return z: set if a is a floor
IsFloorTile:
    cp a, $1C
    ret
