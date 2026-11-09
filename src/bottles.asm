; bottles.asm — μπουκάλια: διάταξη στην οθόνη, σχεδίαση, γραμμές υγρού

; Εγγραφή μπουκαλιού (BOT_SIZE bytes, στο bottles)
B_X             equ 0           ; στήλη (byte)
B_Y             equ 1           ; πρώτη γραμμή, όταν δεν είναι σηκωμένο
B_CAP           equ 2           ; χωρητικότητα (στρώσεις)
B_CNT           equ 3           ; στρώσεις μέσα
B_LH            equ 4           ; γραμμές ανά στρώση (60 / cap)
B_RAISE         equ 5           ; 0 ή RAISE_H όταν είναι επιλεγμένο
B_DONE          equ 6           ; 1 = ολοκληρωμένο (ένα χρώμα, γεμάτο)
B_ROW           equ 7           ; 0 / 1
B_LAY           equ 8           ; στρώσεις από κάτω: pen, bit 7 = κρυμμένη
BOT_SIZE        equ 16
MAX_BOTTLES     equ 14
MAX_CAP         equ 6

ROW_Y1          equ 28          ; δύο σειρές
ROW_Y2          equ 118
ONE_ROW_Y       equ 70          ; ως ROW_MAX μπουκάλια: μία σειρά
ROW_MAX         equ 5
BOTTLE_PITCH    equ 11          ; bytes
RAISE_H         equ 8
CURSOR_DY       equ BOTTLE_H+2  ; ο κέρσορας κάτω από το μπουκάλι

; IX = μπουκάλι A. Αλλάζει DE.
bottle_ix:
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,bottles
        add hl,de
        push hl
        pop ix
        pop hl
        ret

; Φορτώνει μια διάταξη. in: HL = δεδομένα:
;   db πλήθος, χωρητικότητα, μετά ανά μπουκάλι: db στρώσεις, pens...
; Μοιράζει τα μπουκάλια σε σειρές και τα κεντράρει.
level_setup:
        ld a,(hl)
        inc hl
        ld (nbottles),a
        ld b,a
        ld a,(hl)
        inc hl
        ld (level_cap),a
        ld a,b                  ; μπουκάλια ανά σειρά
        cp ROW_MAX+1
        jr c,.one
        inc a
        srl a                   ; (n+1)/2 στην επάνω σειρά
        ld (row_len),a
        ld c,a
        ld a,b
        sub c
        ld (row_len+1),a
        ld a,2
        jr .rows
.one:   ld (row_len),a
        xor a
        ld (row_len+1),a
        inc a
.rows:  ld (nrows),a
        xor a
        ld (row_start),a
        ld a,(row_len)
        ld (row_start+1),a

        ld ix,bottles
        xor a                   ; σειρά
        ld (tmp_row),a
.row:   ld a,(tmp_row)
        ld e,a
        ld d,0
        push hl
        ld hl,row_len
        add hl,de
        ld b,(hl)               ; μπουκάλια στη σειρά
        pop hl
        ld c,0                  ; x0 = (80 - (n*PITCH - 3)) / 2
.mul:   ld a,c
        add a,BOTTLE_PITCH
        ld c,a
        djnz .mul
        ld a,(tmp_row)
        ld e,a
        push hl
        ld hl,row_len
        add hl,de
        ld b,(hl)
        pop hl
        ld a,80+3
        sub c
        srl a
        ld c,a                  ; C = x
        ld a,(tmp_row)
        or a
        jr nz,.r2
        ld a,(row_len)          ; ίσες σειρές: η επάνω μισό βήμα αριστερά
        ld e,a
        ld a,(row_len+1)
        cp e
        jr nz,.r1
        ld a,c
        sub 3
        ld c,a
.r1:    ld a,c
        ld (tmp_x0),a
        jr .xok
.r2:    ld a,(tmp_x0)           ; η κάτω: μισό βήμα (6 bytes) από την επάνω,
        add a,6                 ; ώστε ο πίδακας από σειρά σε σειρά να
        ld c,a                  ; πέφτει στο κενό ανάμεσα στα μπουκάλια
.xok:
        ld a,(nrows)            ; y της σειράς
        dec a
        ld a,ONE_ROW_Y
        jr z,.y
        ld a,(tmp_row)
        or a
        ld a,ROW_Y1
        jr z,.y
        ld a,ROW_Y2
.y:     ld (tmp_y),a
.bot:   ld (ix+B_X),c
        ld a,(tmp_y)
        ld (ix+B_Y),a
        ld a,(tmp_row)
        ld (ix+B_ROW),a
        ld a,(level_cap)
        ld (ix+B_CAP),a
        push bc
        ld c,a                  ; B_LH = BODY_LINES / cap
        ld a,BODY_LINES
        ld b,-1
.div:   inc b
        sub c
        jr nc,.div
        ld (ix+B_LH),b
        pop bc
        xor a
        ld (ix+B_RAISE),a
        ld (ix+B_DONE),a
        ld a,(hl)               ; στρώσεις
        inc hl
        ld (ix+B_CNT),a
        or a
        jr z,.empty
        push bc
        ld b,a
        push ix
.lay:   ld a,(hl)
        inc hl
        ld (ix+B_LAY),a
        inc ix
        djnz .lay
        pop ix
        pop bc
.empty: call check_done
        ld de,BOT_SIZE
        add ix,de
        ld a,c
        add a,BOTTLE_PITCH
        ld c,a
        djnz .bot
        ld a,(tmp_row)
        inc a
        ld (tmp_row),a
        ld e,a
        ld a,(nrows)
        cp e
        jp nz,.row
        ret

; B_DONE = 1 αν το μπουκάλι είναι γεμάτο με ένα χρώμα. IX = μπουκάλι.
check_done:
        ld (ix+B_DONE),0
        ld a,(ix+B_CNT)
        cp (ix+B_CAP)
        ret nz
        push bc
        push ix
        ld b,a
        ld a,(ix+B_LAY)
.cmp:   cp (ix+B_LAY)
        jr nz,.no
        inc ix
        djnz .cmp
        pop ix
        pop bc
        bit 7,a                 ; κρυμμένες δεν μετράνε
        ret nz
        ld (ix+B_DONE),1
        ret
.no:    pop ix
        pop bc
        ret

;------------------------------------------------------------------
; Γραμμή υγρού. in: IX = μπουκάλι, A = γραμμή από κάτω (0..59),
; C = pen (0 = άδεια). Κρατάει τα BC, IX.
liquid_row:
        push bc
        ld b,a
        ld a,(ix+B_Y)
        sub (ix+B_RAISE)
        add a,BODY_BOTTOM
        sub b
        ld c,(ix+B_X)
        inc c
        call scr_addr
        pop bc
        push bc
        ld a,c
        or a
        jr z,.empty
        ld e,c
        ld d,0
        push hl
        ld hl,pen_left
        add hl,de
        ld a,(hl)
        or PR_WHITE             ; λάμψη στο pixel 3
        ld b,a
        ld hl,pen_both
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),b
        jr .rest
.empty: ld (hl),PR_GLASS
.rest:  inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        pop bc
        ret

; Ολόκληρο μπουκάλι (γυαλί, υγρό, φελλός). IX = μπουκάλι.
draw_bottle:
        ld a,(ix+B_Y)
        sub (ix+B_RAISE)
        ld c,(ix+B_X)
        call scr_addr
        ex de,hl
        ld hl,bottle_gfx
        ld bc,BOTTLE_H*256+BOTTLE_W
        call draw_sprite
        ld a,(ix+B_CNT)
        or a
        ret z
        xor a
        ld (row_n),a
        push ix
        pop hl
        ld de,B_LAY
        add hl,de               ; HL -> στρώσεις
        ld b,(ix+B_CNT)
.lay:   push bc
        ld a,(hl)
        inc hl
        bit 7,a
        jr z,.pen
        ld a,PEN_HIDDEN
.pen:   ld c,a
        push hl
        ld b,(ix+B_LH)
.row:   ld a,(row_n)
        call liquid_row
        ld hl,row_n
        inc (hl)
        djnz .row
        pop hl
        pop bc
        djnz .lay
        ld a,(ix+B_DONE)
        or a
        ret z
        ; φελλός
        ld a,(ix+B_Y)
        sub (ix+B_RAISE)
        ld c,(ix+B_X)
        inc c
        inc c
        call scr_addr
        ex de,hl
        ld hl,cork_gfx
        ld bc,CORK_H*256+CORK_W
        jp draw_sprite

; Σβήνει και ξανασχεδιάζει (για σήκωμα / κατέβασμα). IX = μπουκάλι.
redraw_bottle:
        ld a,(ix+B_Y)
        sub RAISE_H
        ld c,(ix+B_X)
        call scr_addr
        ld bc,(BOTTLE_H+RAISE_H)*256+BOTTLE_W
        call clear_rect
        jp draw_bottle

draw_all_bottles:
        ld a,(nbottles)
        ld b,a
        ld ix,bottles
.bot:   push bc
        call draw_bottle
        ld de,BOT_SIZE
        add ix,de
        pop bc
        djnz .bot
        ret

; Κέρσορας κάτω από το μπουκάλι A. Με σβήσιμο: cursor_erase.
cursor_draw:
        call cursor_addr
        ex de,hl
        ld hl,cursor_gfx
        ld bc,CURSOR_H*256+CURSOR_W
        jp draw_sprite

cursor_erase:
        call cursor_addr
        ld bc,CURSOR_H*256+CURSOR_W
        jp clear_rect

cursor_addr:
        call bottle_ix
        ld a,(ix+B_Y)
        add a,CURSOR_DY
        ld c,(ix+B_X)
        inc c
        inc c
        jp scr_addr
