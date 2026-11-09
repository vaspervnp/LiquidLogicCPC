; ui.asm — οθόνες: τίτλος, επιλογή πίστας, αστέρια και πρόοδος

MODE_TITLE      equ 0
MODE_SELECT     equ 1
MODE_GAME       equ 2

GRID_Y          equ 22          ; επιλογή πίστας: 10 x 10 κελιά
GRID_DY         equ 18
CELL_W          equ 8           ; bytes

; Ανά καρέ, ανάλογα με την οθόνη.
mode_frame:
        ld a,(mode)
        cp MODE_GAME
        jp z,game_frame
        cp MODE_SELECT
        jp z,select_frame
        jp title_frame

;------------------------------------------------------------------
; Τίτλος: «LIQUID LOGIC» με μεγάλα γράμματα που κάθε γραμμή τους έχει άλλο
; υγρό, πέντε γεμάτα μπουκάλια, «PRESS SPACE».
title_start:
        xor a
        ld (mode),a
        ld (relax),a
        call music_start
        call cls
        ld hl,title_bottles
        call level_setup
        call draw_all_bottles
        ld hl,str_title1
        ld bc,10*256+28
        call print_big
        ld hl,str_title2
        ld bc,34*256+30
        call print_big
        ld hl,str_press
        ld bc,160*256+21
        ld a,PEN_WHITE
        call print_str
        ld hl,str_machine
        ld bc,182*256+24
        ld a,PEN_GLASS
        jp print_str

title_frame:
        ld a,(input_new)        ; R: «Χαλάρωση»
        and IN_RESTART
        jr z,.fire
        ld a,1
        ld (relax),a
        ld (relax_new),a
        ld hl,sfx_select
        call play_sfx
        ld a,MODE_GAME
        ld (mode),a
        jp level_start
.fire:  ld a,(input_new)
        and IN_FIRE
        ret z
        ld hl,sfx_select
        call play_sfx
        jp select_start

; Πέντε ολοκληρωμένα μπουκάλια (μορφή πίστας, levels.asm).
title_bottles:
        db 0,5,4,0,0,0
        db 0,0,0,4, 4,4,4,4
        db 0,0,0,4, 6,6,6,6
        db 0,0,0,4, 7,7,7,7
        db 0,0,0,4, 9,9,9,9
        db 0,0,0,4, 12,12,12,12

; Μεγάλα γράμματα: κάθε pixel του font 3x5 γίνεται 1 byte x 4 γραμμές, και
; κάθε γραμμή του γλύφου έχει το δικό της pen (big_pens). in: HL = κείμενο,
; B = y, C = x (byte).
print_big:
.ch:    ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push bc
        sub 32
        ld e,a
        ld d,0
        ld hl,font_map
        add hl,de
        ld l,(hl)               ; δείκτης x 10
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,font_gfx
        add hl,de
        ex de,hl                ; DE = γλύφος
        ld a,b
        call scr_addr           ; HL = οθόνη
        ld ix,big_pens
        ld b,5
.row:   push bc
        ld a,(ix+0)             ; pen_both της γραμμής
        inc ix
        push hl
        ld l,a
        ld h,0
        ld bc,pen_both
        add hl,bc
        ld c,(hl)               ; C = byte του pen
        pop hl
        ld a,(de)               ; 4 pixels -> big_row[0..3]
        inc de
        ld b,a
        and #AA
        call nz,.on
        ld (big_row),a
        ld a,b
        and #55
        call nz,.on
        ld (big_row+1),a
        ld a,(de)
        inc de
        ld b,a
        and #AA
        call nz,.on
        ld (big_row+2),a
        ld a,b
        and #55
        call nz,.on
        ld (big_row+3),a
        ld b,4                  ; 4 γραμμές της οθόνης
.line:  push hl
        push de
        ex de,hl
        ld hl,big_row
        ldi
        ldi
        ldi
        ldi
        pop de
        pop hl
        NEXT_LINE
        djnz .line
        pop bc
        djnz .row
        pop bc
        pop hl
        ld a,c
        add a,4
        ld c,a
        jp .ch
.on:    ld a,c
        ret

big_pens:       db 13,4,5,6,7   ; ροζ, κόκκινο, πορτοκαλί, κίτρινο, πράσινο

;------------------------------------------------------------------
; Επιλογή πίστας: 10 x 10 κελιά με τον αριθμό και τρία αστέρια. Κλειδωμένες
; (πέρα από το unlocked) σε γκρι, ολοκληρωμένες σε κίτρινο.
select_start:
        ld a,MODE_SELECT
        ld (mode),a
        call music_start
        call cls
        ld hl,str_select
        ld bc,2*256+28
        ld a,PEN_WHITE
        call print_str
        xor a
.cell:  push af
        call draw_cell
        pop af
        inc a
        cp LEVEL_COUNT
        jr nz,.cell
        ld a,(level)            ; ο κέρσορας στην τελευταία πίστα
        ld (sel_level),a
        ld c,PEN_WHITE
        jp cell_frame

select_frame:
        ld a,(input_new)
        and IN_ESC
        jp nz,title_start
        ld a,(input_new)
        and IN_FIRE
        jr z,.move
        ld a,(sel_level)        ; μόνο ξεκλείδωτες
        ld hl,unlocked
        cp (hl)
        ld hl,sfx_error
        jp nc,play_sfx
        ld (level),a
        ld hl,sfx_select
        call play_sfx
        ld a,MODE_GAME
        ld (mode),a
        jp level_start
.move:  ld a,(input_new)
        and IN_LEFT|IN_RIGHT|IN_UP|IN_DOWN
        ret z
        ld b,a
        push bc
        ld hl,sfx_tick
        call play_sfx
        ld a,(sel_level)        ; σβήσιμο του πλαισίου
        ld c,PEN_BG
        call cell_frame
        pop bc
        ld a,(sel_level)
        bit 2,b                 ; IN_LEFT
        jr z,.r
        sub 1
        jr nc,.r
        ld a,LEVEL_COUNT-1
.r:     bit 3,b                 ; IN_RIGHT
        jr z,.u
        inc a
        cp LEVEL_COUNT
        jr c,.u
        xor a
.u:     bit 0,b                 ; IN_UP
        jr z,.d
        sub 10
        jr nc,.d
        add a,LEVEL_COUNT
.d:     bit 1,b                 ; IN_DOWN
        jr z,.set
        add a,10
        cp LEVEL_COUNT
        jr c,.set
        sub LEVEL_COUNT
.set:   ld (sel_level),a
        ld c,PEN_WHITE
        jp cell_frame

; A = πίστα -> B = y, C = x (byte) του κελιού.
cell_xy:
        ld b,0
.div:   cp 10
        jr c,.col
        sub 10
        inc b
        jr .div
.col:   add a,a                 ; x = στήλη * 8
        add a,a
        add a,a
        ld c,a
        ld a,b                  ; y = GRID_Y + σειρά * 18
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,GRID_Y
        ld b,a
        ret

; Κελί της πίστας A: αριθμός και αστέρια.
draw_cell:
        ld e,a
        ld d,0
        ld hl,stars
        add hl,de
        ld a,(hl)
        ld (tmp_stars),a
        ld a,e
        ld hl,unlocked
        cp (hl)
        ld a,PEN_GLASS          ; κλειδωμένη
        jr nc,.pen
        ld a,(tmp_stars)
        or a
        ld a,PEN_WHITE
        jr z,.pen
        ld a,PEN_LIQUID+2       ; ολοκληρωμένη
.pen:   ld (tmp_pen),a
        ld a,e
        push af
        inc a
        call num_str
        pop af
        push af
        call cell_xy
        pop af
        ld hl,num_buf+1         ; 2 ψηφία στο κέντρο, 3 από το 100
        inc c
        inc c
        cp 99
        jr c,.num
        dec hl
        dec c
.num:   push bc
        ld a,(tmp_pen)
        call print_str
        pop bc
        ; τρία αστεράκια κάτω από τον αριθμό: κίτρινα όσα έχει κερδίσει
        ld a,b
        add a,12
        ld b,a
        ld a,c
        and #F8
        inc a
        ld c,a
        ld e,0                  ; αστέρι 0..2
.star:  push bc
        push de
        ld a,(tmp_pen)          ; κλειδωμένη: χωρίς αστέρια
        cp PEN_GLASS
        ld a,PEN_BG
        jr z,.put
        ld a,(tmp_stars)        ; κίτρινο αν αστέρια > E, αλλιώς γκρι
        cp e
        ld a,PEN_GLASS
        jr z,.put
        jr c,.put
        ld a,PEN_LIQUID+2
.put:   ld e,a
        ld d,0
        ld hl,pen_both
        add hl,de
        ld e,(hl)
        ld a,b
        call scr_addr
        ld (hl),e
        ld a,h
        add a,8
        ld h,a
        ld (hl),e
        pop de
        pop bc
        inc c
        inc c
        inc e
        ld a,e
        cp 3
        jr nz,.star
        ret

; Πλαίσιο γύρω από το κελί A, στο pen C (PEN_BG = σβήσιμο).
cell_frame:
        push bc
        call cell_xy
        pop de
        ld d,0
        ld hl,pen_both
        add hl,de
        ld e,(hl)               ; E = byte του pen
        ld a,b
        sub 3
        ld b,a
        push bc
        call scr_addr           ; επάνω γραμμή
        call .hline
        pop bc
        push bc
        ld a,b
        add a,18
        call scr_addr           ; κάτω γραμμή
        call .hline
        pop bc
        ld d,18                 ; πλευρές
.side:  push bc
        push de
        ld a,b
        call scr_addr
        pop de
        ld (hl),e
        ld a,l
        add a,CELL_W-1
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld (hl),e
        pop bc
        inc b
        dec d
        jr nz,.side
        ret
.hline: ld b,CELL_W
.hb:    ld (hl),e
        inc hl
        djnz .hb
        ret

;------------------------------------------------------------------
; Αστέρια για τη νίκη στην πίστα level με moves κινήσεις: 3 ως το par,
; 2 ως par + par/4 + 1, αλλιώς 1. Κρατάει το καλύτερο και ξεκλειδώνει την
; επόμενη. out: A = αστέρια αυτής της φοράς.
award_stars:
        ld a,(level_par)
        ld b,a
        ld a,(moves)
        ld c,3
        cp b
        jr z,.got
        jr c,.got
        dec c
        ld d,a
        ld a,b
        srl a
        srl a
        add a,b
        inc a
        cp d
        jr nc,.got
        dec c
.got:   ld a,(level)
        ld e,a
        ld d,0
        ld hl,stars
        add hl,de
        ld a,c
        cp (hl)
        jr c,.keep
        jr z,.keep
        ld (hl),a
        ld a,1
        ld (save_dirty),a
.keep:  ld a,(level)            ; ξεκλείδωμα της επόμενης
        add a,2
        cp LEVEL_COUNT+1
        jr c,.lim
        ld a,LEVEL_COUNT
.lim:   ld hl,unlocked
        cp (hl)
        jr c,.done
        jr z,.done
        ld (hl),a
        ld a,1
        ld (save_dirty),a
.done:  ld a,c
        ret

str_title1:     db "LIQUID",0
str_title2:     db "LOGIC",0
str_press:      db "SPACE PLAY  R RELAX",0
str_machine:    db "AMSTRAD CPC 6128",0
str_select:     db "SELECT LEVEL",0
