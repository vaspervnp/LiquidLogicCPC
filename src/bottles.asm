; bottles.asm — μπουκάλια: διάταξη στην οθόνη, σχεδίαση, γραμμές υγρού,
; σημάνσεις των ειδικών τύπων (κρυμμένες, πάγος, λουκέτο, κουρτίνα, σταγονόμετρο)

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
B_FLAGS         equ 14          ; BF_*
B_FREEZE        equ 15          ; κινήσεις ως το ξεπάγωμα (0 = όχι πάγος)
B_LOCK          equ 16          ; pen του λουκέτου (0 = όχι)
B_TILT          equ 17          ; γέρσιμο στη μετάγγιση: 1 δεξιά, -1 αριστερά, 0
BOT_SIZE        equ 24
MAX_BOTTLES     equ 14
MAX_CAP         equ 6

BF_CAP          equ 7           ; bflags της πίστας: χωρητικότητα (0 = της πίστας)
BF_DROPPER      equ 8           ; μία στρώση τη φορά
BF_CURTAIN      equ 16          ; κρυμμένο ως την πρώτη μετάγγιση
BFB_DROPPER     equ 3
BFB_CURTAIN     equ 4

LF_HIDDEN       equ 1           ; flags της πίστας
LF_MOVES        equ 2
LF_TIMER        equ 4
LF_EXTRA        equ 8

ROW_Y1          equ 28          ; δύο σειρές
ROW_Y2          equ 118
ONE_ROW_Y       equ 70          ; ως ROW_MAX μπουκάλια: μία σειρά
ROW_MAX         equ 5
BOTTLE_PITCH    equ 11          ; bytes
RAISE_H         equ 8
CURSOR_DY       equ BOTTLE_H+2  ; ο κέρσορας κάτω από το μπουκάλι
CURTAIN_PEN     equ 11          ; μωβ ρίγες με γκρι
LOCK_DY         equ BODY_TOP+24

; IX = μπουκάλι A. Αλλάζει DE.
bottle_ix:
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; x 24
        ld de,bottles
        add hl,de
        push hl
        pop ix
        pop hl
        ret

; A = πρώτη γραμμή του μπουκαλιού IX στην οθόνη.
bottle_top:
        ld a,(ix+B_Y)
        sub (ix+B_RAISE)
        ret

; Φορτώνει μια πίστα (plan.md §6, assets/data/levels.asm). in: HL =
;   header:   db flags, μπουκάλια, χωρητικότητα, κινήσεις, χρονόμετρο, par
;   μπουκάλι: db bflags, freeze, lock, πλήθος, pens από κάτω...
level_setup:
        ld de,level_flags
        ldi
        ld a,(hl)
        inc hl
        ld (nbottles),a
        ld a,(hl)
        inc hl
        ld (level_cap),a
        ld de,level_moves
        ldi
        ldi
        ldi
        ld a,(nbottles)
        ld b,a
        ld ix,bottles
.bot:   push bc
        ld a,(hl)               ; bflags
        inc hl
        ld c,a
        and #FF-BF_CAP
        ld (ix+B_FLAGS),a
        ld a,c
        and BF_CAP
        jr nz,.cap
        ld a,(level_cap)
.cap:   call bottle_init
        ld a,(hl)
        inc hl
        ld (ix+B_FREEZE),a
        ld a,(hl)
        inc hl
        ld (ix+B_LOCK),a
        ld a,(hl)               ; στρώσεις
        inc hl
        ld (ix+B_CNT),a
        or a
        jr z,.empty
        ld b,a
        push ix
.lay:   ld a,(hl)
        inc hl
        ld (ix+B_LAY),a
        inc ix
        djnz .lay
        pop ix
.empty: call check_done
        ld de,BOT_SIZE
        add ix,de
        pop bc
        djnz .bot
        jp layout

; Άδειο μπουκάλι IX χωρητικότητας A (χωρίς θέση· layout).
bottle_init:
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
        ld (ix+B_CNT),a
        ld (ix+B_FREEZE),a
        ld (ix+B_LOCK),a
        ld (ix+B_TILT),a
        ret

; Γέρσιμο (B_TILT): κάθε γραμμή του μπουκαλιού μετατοπίζεται οριζόντια κατά
; tilt_table pixels (4 στο χείλος ως 0 στον πάτο: διάτμηση). Οι μονές
; μετατοπίσεις σχεδιάζονται με το bottle_gfx_odd (1 pixel δεξιά).
; in: A = γραμμή μέσα στο μπουκάλι (0 = χείλος), IX. out: A = pixels (signed).
tilt_px:
        bit 7,(ix+B_TILT)       ; (τα bit/inc/dec κρατάνε το A)
        jr nz,.on
        inc (ix+B_TILT)
        dec (ix+B_TILT)
        jr nz,.on
        xor a
        ret
.on:    push hl
        push de
        ld l,a
        ld h,0
        ld de,tilt_table
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        bit 7,(ix+B_TILT)
        ret z
        neg
        ret

; Το ίδιο, σε bytes (στρογγύλεμα προς τα κάτω).
tilt_dx:
        call tilt_px
        sra a
        ret

; Μοιράζει τα nbottles μπουκάλια σε σειρές και τα κεντράρει (B_X, B_Y, B_ROW).
layout:
        ld a,(nbottles)
        ld b,a
        cp ROW_MAX+1            ; μπουκάλια ανά σειρά
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
        ld hl,row_len
        add hl,de
        ld b,(hl)               ; μπουκάλια στη σειρά
        push bc
        ld c,0                  ; x0 = (80 - (n*PITCH - 3)) / 2
.mul:   ld a,c
        add a,BOTTLE_PITCH
        ld c,a
        djnz .mul
        pop de
        ld b,d
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
.y:     ld e,a
        ld a,(tmp_row)
        ld d,a
.bot:   ld (ix+B_X),c
        ld (ix+B_Y),e
        ld (ix+B_ROW),d
        push de
        ld de,BOT_SIZE
        add ix,de
        pop de
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

; B_DONE = 1 αν το μπουκάλι είναι γεμάτο με ένα χρώμα (και οι κρυμμένες του
; στρώσεις αποκαλύπτονται). IX = μπουκάλι.
check_done:
        ld (ix+B_DONE),0
        ld a,(ix+B_CNT)
        cp (ix+B_CAP)
        ret nz
        push bc
        push ix
        ld b,a
        ld a,(ix+B_LAY)
        and #7F
        ld c,a
.cmp:   ld a,(ix+B_LAY)
        and #7F
        cp c
        jr nz,.no
        inc ix
        djnz .cmp
        pop ix
        push ix
        ld b,(ix+B_CNT)
.show:  res 7,(ix+B_LAY)        ; ολοκληρωμένο: όλο ορατό
        inc ix
        djnz .show
        pop ix
        pop bc
        ld (ix+B_DONE),1
        ret
.no:    pop ix
        pop bc
        ret

;------------------------------------------------------------------
; Γραμμή υγρού. in: IX = μπουκάλι, A = γραμμή από κάτω (0..59),
; C = pen (0 = άδεια). Κρατάει τα BC, IX. Με μονή μετατόπιση γερσίματος η
; γραμμή πιάνει 7 bytes, με τα pixels του γυαλιού στις άκρες.
liquid_row:
        push bc
        ld b,a
        ld a,(ix+B_TILT)        ; όρθιο: χωρίς το tilt_px (A = D = 0)
        ld d,a
        or a
        jr z,.x
        ld a,BODY_BOTTOM
        sub b
        call tilt_px
        ld d,a                  ; D = μετατόπιση σε pixels
        sra a
.x:     inc a
        add a,(ix+B_X)
        ld c,a
        ld a,(ix+B_Y)
        sub (ix+B_RAISE)
        add a,BODY_BOTTOM
        sub b
        call scr_addr
        pop bc
        push bc
        bit 0,d
        jr nz,.odd
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
.odd:   ld a,c                  ; γυαλί|υγρό, λάμψη|υγρό, 4 × υγρό, υγρό|γυαλί
        or a
        jr z,.oempty
        ld e,c
        ld d,0
        push hl
        ld hl,pen_right
        add hl,de
        ld b,(hl)
        ld hl,pen_left
        add hl,de
        ld a,(hl)
        or PR_GLASS
        ld c,a
        ld hl,pen_both
        add hl,de
        ld e,(hl)
        pop hl
        ld a,b
        or PL_GLASS
        ld (hl),a
        inc hl
        ld a,b
        or PL_WHITE
        ld (hl),a
        ld a,e
        jr .omid
.oempty:
        ld (hl),PL_GLASS
        inc hl
        ld (hl),PL_GLASS
        xor a
        ld c,PR_GLASS
.omid:  inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),c
        pop bc
        ret

; Ολόκληρο μπουκάλι (γυαλί, υγρό, σημάνσεις, φελλός). IX = μπουκάλι.
draw_bottle:
        ld a,(ix+B_TILT)
        or a
        jr nz,.tilted
        call bottle_top
        ld c,(ix+B_X)
        call scr_addr
        ex de,hl
        ld hl,bottle_gfx
        ld bc,BOTTLE_H*256+BOTTLE_W
        call draw_sprite
        jr .liquid
.tilted:                        ; γραμμή-γραμμή, με τη μετατόπιση του γερσίματος
        xor a
        ld (tilt_row),a
.trow:  ld a,(tilt_row)
        call tilt_px
        ld b,a
        sra a
        add a,(ix+B_X)
        ld c,a
        push bc
        call bottle_top
        ld b,a
        ld a,(tilt_row)
        add a,b
        call scr_addr
        ex de,hl
        pop bc
        ld a,(tilt_row)         ; HL = γραμμή του bottle_gfx ή του _odd
        ld l,a
        ld h,0
        bit 0,b
        jr nz,.t9
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,bottle_gfx
        add hl,bc
        ld bc,BOTTLE_W
        jr .tcp
.t9:    ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,bottle_gfx_odd
        add hl,bc
        ld bc,BOTTLE_W+1
.tcp:   ldir
        ld hl,tilt_row
        inc (hl)
        ld a,(hl)
        cp BOTTLE_H
        jr nz,.trow
.liquid:
        ld a,(ix+B_CNT)
        or a
        jr z,draw_marks
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

; Κουρτίνα ή «?», πάγος, λουκέτο, φελλός ή βολβός. IX = μπουκάλι.
draw_marks:
        bit BFB_CURTAIN,(ix+B_FLAGS)
        call nz,draw_curtain
        bit BFB_CURTAIN,(ix+B_FLAGS)
        call z,draw_hidden_q
        ld a,(ix+B_FREEZE)
        or a
        call nz,draw_ice
        ld a,(ix+B_LOCK)
        or a
        call nz,draw_lock
        ld a,(level_cap)
        cp (ix+B_CAP)
        call nz,draw_ticks
        ld hl,cork_gfx
        ld a,(ix+B_DONE)
        or a
        jr nz,.top
        bit BFB_DROPPER,(ix+B_FLAGS)
        ret z
        ld hl,bulb_gfx
.top:   push hl                 ; φελλός / βολβός στο λαιμό
        xor a
        call tilt_dx
        add a,(ix+B_X)
        inc a
        inc a
        ld c,a
        call bottle_top
        call scr_addr
        ex de,hl
        pop hl
        ld bc,CORK_H*256+CORK_W
        jp draw_sprite

; Άλλη χωρητικότητα από της πίστας: λευκές εγκοπές και στους δύο τοίχους
; (γυαλί, που δεν το αγγίζει το υγρό), στα όρια των στρώσεων.
draw_ticks:
        ld a,(ix+B_TILT)        ; γερμένο: χωρίς εγκοπές ως το pour_finish
        or a
        ret nz
        ld b,(ix+B_CAP)
        dec b
        ret z
        call bottle_top
        add a,BODY_BOTTOM+1
.tick:  sub (ix+B_LH)
        push af
        push bc
        ld c,(ix+B_X)
        call scr_addr
        ld de,BOTTLE_W-1
        ld c,2                  ; 2 γραμμές (μία αν αλλάζει σειρά χαρακτήρων)
.line:  ld a,PB_WHITE           ; byte 0 και byte 7: τοίχος + έξω pixel, λευκά
        ld (hl),a
        add hl,de
        ld (hl),a
        sbc hl,de               ; (το add δεν άφησε carry)
        ld a,h
        add a,8
        jr c,.done
        ld h,a
        dec c
        jr nz,.line
.done:  pop bc
        pop af
        djnz .tick
        ret

; Κουρτίνα: κάθετες ρίγες σε όλο το σώμα.
draw_curtain:
        ld a,(pen_left+CURTAIN_PEN)
        ld e,a
        ld a,(pen_right+PEN_GLASS)
        or e
        ld e,a
        call bottle_top
        add a,BODY_TOP
        ld c,(ix+B_X)
        inc c
        call scr_addr
        ld b,BODY_LINES
.ln:    push hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        pop hl
        NEXT_LINE
        djnz .ln
        ret

; «?» στη μέση κάθε κρυμμένης στρώσης.
draw_hidden_q:
        ld a,(ix+B_CNT)
        or a
        ret z
        ld b,a
        push ix
        pop hl
        ld de,B_LAY
        add hl,de               ; HL -> στρώσεις
        ld a,(ix+B_LH)
        srl a
        add a,2
        ld d,a
        call bottle_top
        add a,BODY_BOTTOM
        sub d
        ld c,a                  ; C = y του «?» στη στρώση 0
.lay:   bit 7,(hl)
        jr z,.next
        push bc
        push hl
        call bottle_top         ; μετατόπιση του γερσίματος στη γραμμή C
        ld b,a
        ld a,c
        sub b
        call tilt_dx
        add a,(ix+B_X)
        add a,3
        ld b,c
        ld c,a
        ld a,b
        call scr_addr
        ex de,hl
        ld hl,hidden_q_gfx
        ld bc,5*256+2
        call draw_sprite
        pop hl
        pop bc
.next:  inc hl
        ld a,c
        sub (ix+B_LH)
        ld c,a
        djnz .lay
        ret

; Πάγος: λευκές κουκκίδες κάθε 3 γραμμές, σε εναλλασσόμενα bytes (σαν
; κρύσταλλοι), και οι κινήσεις ως το ξεπάγωμα στη μέση.
draw_ice:
        call bottle_top
        add a,BODY_TOP+1
        ld c,(ix+B_X)
        inc c
        call scr_addr
        ld b,BODY_LINES/3
        ld d,0                  ; 0/1: ζυγά ή μονά bytes
.ln:    push hl
        ld a,d
        or a
        jr z,.even
        inc hl
.even:  ld e,3
.byte:  ld a,(hl)
        and #55
        or PL_WHITE
        ld (hl),a
        inc hl
        inc hl
        dec e
        jr nz,.byte
        pop hl
        ld a,d
        xor 1
        ld d,a
        NEXT_LINE
        NEXT_LINE
        NEXT_LINE
        djnz .ln
        ld a,(ix+B_FREEZE)
        call num_str
        ld hl,num_buf+1
        ld c,(ix+B_X)
        inc c
        inc c
        ld a,(ix+B_FREEZE)
        cp 10
        jr nc,.two
        inc hl
        inc c
.two:   call bottle_top
        add a,BODY_TOP+25
        ld b,a
        ld a,PEN_WHITE
        jp print_str

; Λουκέτο στο χρώμα B_LOCK (A).
draw_lock:
        ld e,a
        ld d,0
        ld hl,pen_both
        add hl,de
        ld a,(hl)
        ld (tmp_pen),a
        call bottle_top
        add a,LOCK_DY
        ld c,(ix+B_X)
        inc c
        inc c
        call scr_addr
        ex de,hl
        ld hl,lock_gfx
        ld b,LOCK_H
.ln:    push de
        ld c,LOCK_W
.byte:  push bc
        ld a,(tmp_pen)
        ld b,a
        ld c,(hl)               ; λευκό
        inc hl
        ld a,(hl)               ; μάσκα χρώματος
        inc hl
        and b
        or c
        ld (de),a
        inc de
        pop bc
        dec c
        jr nz,.byte
        pop de
        ex de,hl
        NEXT_LINE
        ex de,hl
        djnz .ln
        ret

; Σβήνει και ξανασχεδιάζει (σήκωμα, κατέβασμα, γέρσιμο). Σβήνει και 2 bytes
; δεξιά-αριστερά (για το γέρσιμο), μέσα στο κενό ως τα διπλανά μπουκάλια.
redraw_bottle:
        ld a,(ix+B_X)
        sub 2
        jr nc,.left
        xor a
.left:  ld c,a
        ld a,(ix+B_X)
        add a,BOTTLE_W+2
        cp 81
        jr c,.right
        ld a,80
.right: sub c
        ld e,a                  ; πλάτος
        ld a,(ix+B_Y)
        sub RAISE_H
        call scr_addr
        ld b,BOTTLE_H+RAISE_H
        ld c,e
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
