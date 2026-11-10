; ending.asm — μετά την πίστα 100: «BRAVO!», τα αστέρια, το θέμα NEON που
; ξεκλείδωσε (win_stats), και πυροτεχνήματα: σπίθες (2 x 2) με βαρύτητα, XOR στην
; οθόνη (σβήνονται ξαναγράφοντάς τες), πάνω από το κείμενο.

SPARK_N         equ 32
SP_SIZE         equ 14
SP_X            equ 0           ; 8.8, pixels (0-159)
SP_Y            equ 2           ; 8.8, γραμμές
SP_VX           equ 4
SP_VY           equ 6
SP_LIFE         equ 8           ; 0 = σβησμένη
SP_PEN          equ 9
SP_ADDR         equ 10          ; πού σχεδιάστηκε
SP_VAL          equ 12          ; με ποιο byte (0 = πουθενά)
SPARK_TOP       equ 30
SPARK_BOT       equ 112
SP_GRAV         equ 10

ending_start:
        ld hl,page_end
        ld a,MODE_END
        call text_screen
        call music_start
        ld hl,str_bravo
        ld bc,6*256+28
        call print_big
        ld hl,stars                 ; «STARS N/300»
        ld b,MAX_LEVELS
        ld de,0
.sum:   ld a,(hl)
        inc hl
        add a,e
        ld e,a
        jr nc,.nc
        inc d
.nc:    djnz .sum
        ex de,hl
        call num5_str
        ld bc,134*256+42
        ld a,PEN_LIQUID+2
        call print_str
        ld hl,str_of300
        ld a,PEN_GLASS
        call print_str
        ld hl,sparks                ; καμία σπίθα
        ld de,sparks+1
        ld bc,SPARK_N*SP_SIZE-1
        ld (hl),0
        ldir
        ld a,10
        ld (burst_t),a
        ret

ending_frame:
        ld a,(input_new)
        and IN_FIRE|IN_ESC
        jp nz,title_start
        ld hl,burst_t
        dec (hl)
        call z,burst
        ld ix,sparks
        ld b,SPARK_N
.s:     push bc
        ld a,(ix+SP_VAL)            ; σβήσιμο από την προηγούμενη θέση
        or a
        jr z,.move
        ld c,a
        ld l,(ix+SP_ADDR)
        ld h,(ix+SP_ADDR+1)
        call xor2
        ld (ix+SP_VAL),0
.move:  ld a,(ix+SP_LIFE)
        or a
        jr z,.next
        dec (ix+SP_LIFE)
        jr z,.next
        ld l,(ix+SP_VY)             ; vy += g, y += vy
        ld h,(ix+SP_VY+1)
        ld de,SP_GRAV
        add hl,de
        ld (ix+SP_VY),l
        ld (ix+SP_VY+1),h
        ex de,hl
        ld l,(ix+SP_Y)
        ld h,(ix+SP_Y+1)
        add hl,de
        ld (ix+SP_Y),l
        ld (ix+SP_Y+1),h
        ld a,h
        cp SPARK_TOP
        jr c,.kill
        cp SPARK_BOT
        jr nc,.kill
        ld (spark_y),a
        ld e,(ix+SP_VX)             ; x += vx
        ld d,(ix+SP_VX+1)
        ld l,(ix+SP_X)
        ld h,(ix+SP_X+1)
        add hl,de
        ld (ix+SP_X),l
        ld (ix+SP_X+1),h
        ld a,h
        cp 160
        jr nc,.kill
        ld c,a                      ; byte = x / 2 (σπίθα 2 pixels x 2 γραμμές)
        srl c
        ld e,(ix+SP_PEN)
        ld d,0
        ld hl,pen_both
        add hl,de
        ld a,(hl)
        ld (ix+SP_VAL),a
        ld a,(spark_y)
        call scr_addr
        ld (ix+SP_ADDR),l
        ld (ix+SP_ADDR+1),h
        ld c,(ix+SP_VAL)
        call xor2
        jr .next
.kill:  ld (ix+SP_LIFE),0
.next:  ld de,SP_SIZE
        add ix,de
        pop bc
        dec b
        jp nz,.s
        ret

; XOR του C στο (HL) και στην από κάτω γραμμή.
xor2:
        ld a,(hl)
        xor c
        ld (hl),a
        NEXT_LINE
        ld a,(hl)
        xor c
        ld (hl),a
        ret

; Νέα έκρηξη: 16 σπίθες σε κύκλο (όσες είναι ελεύθερες), τυχαίο σημείο και
; χρώμα υγρού.
burst:
        call rnd
        and 15
        add a,28
        ld (burst_t),a
        call rnd
        and 127
        add a,16
        ld (burst_x),a
        call rnd
        and 31
        add a,46
        ld (burst_y),a
.pen:   call rnd                    ; pen = PEN_LIQUID + (0..11)
        and 15
        cp 12
        jr nc,.pen
        add a,PEN_LIQUID
        ld (burst_pen),a
        ld hl,sfx_cork
        call play_sfx
        ld ix,sparks
        ld iy,spark_dirs
        ld b,SPARK_N
        ld c,16                     ; κατευθύνσεις
.s:     ld a,(ix+SP_LIFE)
        or a
        jr nz,.next
        xor a
        ld (ix+SP_X),a
        ld (ix+SP_Y),a
        ld a,(burst_x)
        ld (ix+SP_X+1),a
        ld a,(burst_y)
        ld (ix+SP_Y+1),a
        ld a,(iy+0)
        ld (ix+SP_VX),a
        ld a,(iy+1)
        ld (ix+SP_VX+1),a
        ld a,(iy+2)
        ld (ix+SP_VY),a
        ld a,(iy+3)
        ld (ix+SP_VY+1),a
        ld a,(burst_pen)
        ld (ix+SP_PEN),a
        push bc
        call rnd
        pop bc
        and 15
        add a,34
        ld (ix+SP_LIFE),a
        ld de,4
        add iy,de
        dec c
        ret z
.next:  ld de,SP_SIZE
        add ix,de
        djnz .s
        ret

; vx (μισή, γιατί το pixel του mode 0 είναι διπλό σε πλάτος), vy - 128
spark_dirs:
        dw 160,-128,  148,-6,    113,98,   61,168
        dw 0,192,     -61,168,  -113,98,  -148,-6
        dw -160,-128, -148,-250, -113,-354, -61,-424
        dw 0,-448,    61,-424,   113,-354, 148,-250

burst_t:        db 0
burst_x:        db 0
burst_y:        db 0
burst_pen:      db 0
spark_y:        db 0
sparks:         ds SPARK_N*SP_SIZE

str_bravo:      db "BRAVO!",0

page_end:
        db 120,CENTER,PEN_WHITE,"ALL 100 LEVELS SOLVED!",0
        db 134,22,PEN_WHITE,"STARS",0
        db 150,CENTER,PEN_LIQUID+5,"NEW THEME UNLOCKED: NEON",0
        db 162,CENTER,PEN_WHITE,"TRY IT IN THE OPTIONS.",0
        db 176,CENTER,PEN_LIQUID+2,"THANK YOU FOR PLAYING!",0
        db 190,CENTER,PEN_GLASS,"SPACE TITLE",0
        db #FF
