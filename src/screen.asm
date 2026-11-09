; screen.asm — οθόνη #C000 (standard, 80 bytes x 200 γραμμές), sprites, κείμενο

; HL = επόμενη γραμμή της οθόνης (μόνο για οθόνη στο #C000). Αλλάζει το A.
        macro NEXT_LINE
        ld a,h
        add a,8
        ld h,a
        jr nc,@ok
        ld a,l
        add a,80
        ld l,a
        ld a,h
        adc a,#C0
        ld h,a
@ok:
        mend

; line_lo[y] / line_hi[y] = διεύθυνση της γραμμής y (πίνακες σε σελίδες).
make_line_table:
        ld hl,line_lo
        ld de,#C000             ; αρχή της σειράς χαρακτήρων
        ld c,25
.row:   ld a,d
        ld b,8
.ln:    ld (hl),e
        inc h
        ld (hl),a
        dec h
        inc l
        add a,8
        djnz .ln
        ld a,e
        add a,80
        ld e,a
        jr nc,.nc
        inc d
.nc:    dec c
        jr nz,.row
        ret

; in: A = y, C = x (byte). out: HL = διεύθυνση.
scr_addr:
        ld l,a
        ld h,hi(line_lo)
        ld a,(hl)
        inc h
        ld h,(hl)
        add a,c
        ld l,a
        ret nc
        inc h
        ret

; Με push (11 T-states ανά 2 bytes, ~4 φορές γρηγορότερα από το ldir). Κάθε
; 128 bytes ανοίγει για λίγο τα interrupts: ό,τι σπρώξει ο handler στη στοίβα
; πέφτει κάτω από το SP, σε οθόνη που δεν έχει καθαριστεί ακόμα (ή, στο τέλος,
; στο αχρησιμοποίητο #BFxx).
cls:
        di
        ld (sp_save),sp
        ld hl,0
        ld sp,hl
        ld a,128
.blk:   ld b,8
.p:     push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        djnz .p
        ei
        nop
        di
        dec a
        jr nz,.blk
        ld sp,(sp_save)
        ei
        ret

; in: HL = γραφικό, DE = οθόνη, B = ύψος, C = πλάτος (bytes).
draw_sprite:
.ln:    push bc
        push de
        ld b,0
        ldir
        pop de
        ex de,hl
        NEXT_LINE
        ex de,hl
        pop bc
        djnz .ln
        ret

; in: HL = οθόνη, B = ύψος, C = πλάτος (bytes). Γεμίζει με pen 0.
clear_rect:
.ln:    push hl
        push bc
        ld b,c
        xor a
.byte:  ld (hl),a
        inc hl
        djnz .byte
        pop bc
        pop hl
        NEXT_LINE
        djnz .ln
        ret

;------------------------------------------------------------------
; Κείμενο με το font 3x5 (κάθε γραμμή διπλή): 2 bytes x 10 γραμμές ανά
; χαρακτήρα. in: HL = κείμενο (0 στο τέλος, ASCII 32-95), B = y, C = x
; (byte), A = pen.
print_str:
        push hl
        ld e,a
        ld d,0
        ld hl,pen_both
        add hl,de
        ld a,(hl)
        ld (txt_pen),a
        pop hl
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
        push hl
        ld a,b
        call scr_addr
        ex de,hl                ; DE = οθόνη
        pop hl                  ; HL = γλύφος
        ld a,(txt_pen)
        ld c,a
        ld b,5
.row:   ld a,(hl)               ; 1η γραμμή
        and c
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        and c
        ld (de),a
        dec de
        dec hl
        ex de,hl
        NEXT_LINE
        ex de,hl
        ld a,(hl)               ; ίδια, 2η γραμμή
        and c
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        and c
        ld (de),a
        dec de
        inc hl
        ex de,hl
        NEXT_LINE
        ex de,hl
        djnz .row
        pop bc
        pop hl
        inc c
        inc c
        jr .ch

; Σβήνει μια γραμμή κειμένου: B = y, C = x (byte), A = χαρακτήρες.
clear_text:
        add a,a
        push af
        ld a,b
        call scr_addr
        pop af
        ld c,a
        ld b,10
        jp clear_rect
