INCLUDE "defines.inc"
INCLUDE "hardware.inc/hardware.inc"

SECTION "Player variables", WRAM0

; 0 = N, 1 = NE, 2 = E, 3 = SE, 4 = S, 5 = SW, 6 = W, 7 = NW
wPlayerFacing: db
wPlayerSubX: db
wPlayerSubY: db

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
    add a, a        ; each entry is 2 bytes, so facing * 2
    ld hl, .deltaTable
    add a, l
    ld l, a
    adc a, h
    sub l
    ld h, a         ; hl now points to the dY entry for this facing

    ld a, [hli]     ; dY
    ld b, a
    ld a, [wShadowOAM + 0]
    add a, b
    ld [wShadowOAM + 0], a
    ld [wShadowOAM + 4], a

    ld a, [hl]      ; dX
    ld b, a
    ld a, [wShadowOAM + 1]
    add a, b
    ld [wShadowOAM + 1], a
    add a, 8
    ld [wShadowOAM + 5], a
    ret

.moveBackward:
    ld a, [wPlayerFacing]
    add a, a
    ld hl, .deltaTable
    add a, l
    ld l, a
    adc a, h
    sub l
    ld h, a

    ld a, [hli]     ; dY — negate it
    cpl
    inc a
    ld b, a
    ld a, [wShadowOAM + 0]
    add a, b
    ld [wShadowOAM + 0], a
    ld [wShadowOAM + 4], a

    ld a, [hl]      ; dX — negate it
    cpl
    inc a
    ld b, a
    ld a, [wShadowOAM + 1]
    add a, b
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
.rightInc
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
