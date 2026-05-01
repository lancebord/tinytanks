INCLUDE "defines.inc"
INCLUDE "hardware.inc/hardware.inc"

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

    ; write HUD to window tilemap
    ld hl, $9C00 ; window tilemap start
    ld a, $9000 ; tank HUD tile index
    ld b, 5
    .hudLives:
        ld [hli], a
        dec b
        jr nz, .hudLives

    ld a, $9000 + 27
    ld b, 5
    .hudBlanks
        ld [hli], a
        dec b
        jr nz, .hudBlanks

    ; load the s =
    ld a, $9000 + 23
    ld [hli], a
    ld a, $9000 + 26
    ld [hli], a

    ; load the zeros
    ld a, $9000 + 1
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

    jr @ ; TODO game logic


SECTION "Tank Sprite", ROMX

TankTiles::
    INCBIN "assets/tank.2bpp"
TankTilesEnd::

SECTION "Level 1 Map", ROMX

Level1Map::
    INCBIN "assets/level1.tilemap"
Level1MapEnd::
