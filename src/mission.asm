INCLUDE "defines.inc"
INCLUDE "hardware.inc/hardware.inc"

DEF MISSION_TENS EQU $98CD
DEF MISSION_ONES EQU $98CE

SECTION "Mission variables", WRAM0

wMissionCountdown: db
wMissionNumber:: db

SECTION "Mission", ROMX

Mission::
    call InitBattleSong
    ; increment the mission number
    ; TODO handle double digit
    ld hl, wMissionNumber
    ld a, [hl]
    inc a
    ld [hl], a

    ; reset the mission countdown
    ld hl, wMissionCountdown
    ld a, 240
    ld [hl], a

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
    ld de, MissionMap
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

    ; Manually set the mission number tile
    ld hl, wMissionNumber
    ld a, [hl]
    inc a ; offset for the tank icon
    ld hl, MISSION_TENS
    ld [hl], a

    ; load the HUD graphics into VRAM
    ; Mission screen uses the same tiles
    ld de, HudTiles
    ld hl, $9000
    ld bc, HudTilesEnd - HudTiles
    call Memcpy

    ld a, %11001111
    ld [hBGP], a

    ; Turn on the LCD with just background enabled
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_BLOCK21
    ldh [hLCDC], a
    ldh [rLCDC], a

    ld hl, wMissionCountdown
.jingleLoop
    push hl
    call WaitVBlank
    pop hl
    dec [hl]
    jr nz, .jingleLoop

    ret

InitBattleSong::
    ld a, 1
    ldh [hSoundUpdate], a
    xor a
    ldh [rAUDENA], a ; Disable audio
    ld a, $FF
    ldh [rAUDENA], a ; Enable audio
    ldh [rAUDTERM], a ; Even pan (mono)
    ld a, $77
    ldh [rAUDVOL], a ; Even volume scale per channel

    ; Initialize hUGETracker
    ld hl, battle_theme
    call hUGE_init

    ret

SECTION "Mission Background", ROMX

MissionMap::
    INCBIN "assets/mission_start.tilemap"
MissionMapEnd::
