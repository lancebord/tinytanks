INCLUDE "defines.inc"
INCLUDE "hardware.inc/hardware.inc"
INCLUDE "hUGE.inc"


SECTION "Intro", ROMX

Intro::
	call InitMainSong
	; Safely wait for VBlank before turning LCD off,
	ld a, LCDC_ENABLE
	ldh [rLCDC], a
	ld a, IE_VBLANK
	ldh [rIE], a
	xor a
	ldh [rIF], a
	halt
	nop             ; guard against halt hardware bug

	; Now we're in VBlank - safe to turn off LCD
	xor a
	ldh [rLCDC], a

	; Copy tiles to VRAM tile block 0 ($8000)
	ld de, TitleTiles
	ld hl, STARTOF(VRAM)
	ld bc, TitleTilesEnd - TitleTiles
	call Memcpy

	; Copy tilemap to background map ($9800)
	ld de, TitleMap
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

	; set bgp
	ld a, %10110100
	ldh [hBGP], a

	; Turn LCD back on
	ld a, LCDC_ON | LCDC_BG_ON | LCDC_BLOCK01 | LCDC_BG_9800
	ldh [hLCDC], a
	ldh [rLCDC], a ; this is necessary cuz there won't be a vblank interrupt until the screen is on
	
.waitStart:
	call WaitVBlank
	ldh a, [hPressedKeys]
	and PAD_START
	jr z, .waitStart

.fadeOut:
	ld hl, .fadePalettes
	ld b, 4
.fadeStep:
	push bc         ; save b (and c) before WaitVBlank destroys them
	push hl         ; save hl too since WaitVBlank destroys it
	call WaitVBlank
	pop hl
	pop bc
	ld a, [hli]
	ldh [hBGP], a
	dec b
	jr nz, .fadeStep
	
	; set the mission to 0 before starting
	ld hl, wMissionNumber
	xor a
	ld [hl], a
	jp Level1

.fadePalettes:
	db %01100000
	db %00010000
	db %00000000
	db %00000000

InitMainSong::
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
	ld hl, title_theme
	call hUGE_init

	ret

; graphical data for intro screen
SECTION "Title Screen Data", ROMX

TitleTiles::
    INCBIN "assets/title_screen.2bpp"
TitleTilesEnd::

TitleMap::
    INCBIN "assets/title_screen.tilemap"
TitleMapEnd::
