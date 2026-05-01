INCLUDE "defines.inc"
INCLUDE "hardware.inc/hardware.inc"

SECTION "Level variables", WRAM0

wUpdateCountdown:: db

SECTION "Level1", ROMX

Level1::
    call Mission
    ; Wait for VBlank then turn LCD off for VRAM swap
    ld a, LCDC_ENABLE
    ldh [rLCDC], a
    ld a, IE_VBLANK
    ldh [rIE], a
    xor a
    ldh [rIF], a
    halt
    nop
    xor a
    ldh [rLCDC], a

    ; Set Tilemap to mission screen
    ld de, Level1Map
    ld hl, TILEMAP0
    ld b, SCREEN_HEIGHT       ; 18 rows
.rowloop:
    ld c, SCREEN_WIDTH        ; copy 20 tiles
    call MemcpySmall
    ; advance hl by 12 to skip the rest of the 32-wide row
    ld a, l
    add a, TILEMAP_WIDTH - SCREEN_WIDTH
    ld l, a
    adc a, h
    sub l
    ld h, a
    dec b
    jr nz, .rowloop

    ; Set BGP
    ld a, %10110100
    ld [hBGP], a

    ; load in the player graphics
    call PlayerInit

    ; write HUD to window tilemap
    ld hl, $9C00 ; window tilemap start
    xor a
    ld b, 5
    .hudLives:
        ld [hli], a
        dec b
        jr nz, .hudLives

    ld a, 27
    ld b, 5
    .hudBlanks
        ld [hli], a
        dec b
        jr nz, .hudBlanks

    ; load the s =
    ld a, 23
    ld [hli], a
    ld a, 26
    ld [hli], a

    ; load the zeros
    ld a, 1
    ld b, 8
    .hudZeros
        ld [hli], a
        dec b
        jr nz, .hudZeros

    ; position the window
    ld a, 7 ; WX = 7 means x = 0
    ldh [rWX], a
    ld a, 136 ; WY = 136 is last row
    ldh [rWY], a

    ; Turn on the LCD with OBJ enabled
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_BLOCK21 | LCDC_WIN_ON | LCDC_WIN_9C00 | LCDC_OBJS | LCDC_OBJ_16
    ldh [hLCDC], a
    ldh [rLCDC], a

    ; reset the level countdown
    ld hl, wUpdateCountdown
    ld a, 12
    ld [hl], a
.main:
    call WaitVBlank

    ; Instant response on fresh press
    ldh a, [hPressedKeys]
    and PAD_LEFT | PAD_RIGHT
    jr z, .checkCountdown
    call PlayerUpdate
    ld a, 12
    ld [wUpdateCountdown], a
    jr .main

.checkCountdown:
    ld hl, wUpdateCountdown
    dec [hl]
    jr nz, .main
    push hl
    call PlayerUpdate
    pop hl
    ld a, 12
    ld [hl], a
    jr .main


SECTION "Tank Sprite", ROMX

TankTiles::
    INCBIN "assets/tank.2bpp"
TankTilesEnd::

SECTION "Level 1 Map", ROMX

Level1Map::
    INCBIN "assets/level1.tilemap"
Level1MapEnd::
