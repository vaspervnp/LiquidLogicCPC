; game.asm — η λογική του παιχνιδιού: πίστες, επιλογή πηγής/στόχου,
; μετάγγιση, κινήσεις, undo, restart, αδιέξοδο, νίκη

ST_IDLE         equ 0           ; κέρσορας
ST_SEL          equ 1           ; πηγή επιλεγμένη (σηκωμένη)
ST_POUR         equ 2           ; ο πίδακας τρέχει
ST_WIN          equ 3

UNDO_MAX        equ 5           ; undo ανά πίστα
UNDO_DEPTH      equ 32          ; κινήσεις που θυμάται
HUD_Y           equ 3

game_start:
        xor a
        ld (level),a
level_start:
        call cls
        ld a,(level)
        add a,a
        ld l,a
        ld h,0
        ld de,level_table
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call level_setup
        xor a
        ld (moves),a
        ld (undo_sp),a
        ld (cursor),a
        ld (state),a
        ld a,UNDO_MAX
        ld (undo_left),a
        call draw_all_bottles
        call hud_draw
        xor a
        jp cursor_draw

game_frame:
        ld a,(state)
        cp ST_POUR
        jp z,.pour
        cp ST_WIN
        jp z,.win
        ld a,(input_new)
        and IN_RESTART
        jp nz,level_start
        ld a,(input_new)
        and IN_UNDO
        jr z,.move
        ld a,(state)
        or a
        call nz,deselect
        jp do_undo
.move:  ld a,(input_new)
        and IN_LEFT|IN_RIGHT|IN_UP|IN_DOWN
        call nz,move_cursor
        ld a,(input_new)
        and IN_ESC
        jr z,.fire
        ld a,(state)
        or a
        ret z
        jp deselect
.fire:  ld a,(input_new)
        and IN_FIRE
        ret z
        ld a,(state)
        or a
        jr nz,.second
        ld a,(cursor)           ; 1η επιλογή: από εδώ αδειάζει
        call bottle_ix
        ld a,(ix+B_CNT)
        or a
        ret z
        ld a,(ix+B_DONE)
        or a
        ret nz
        ld a,(cursor)
        ld (sel_src),a
        ld (ix+B_RAISE),RAISE_H
        call redraw_bottle
        ld a,ST_SEL
        ld (state),a
        ret
.second:
        ld a,(cursor)           ; 2η επιλογή: εδώ γεμίζει
        ld hl,sel_src
        cp (hl)
        jp z,deselect
        ld (sel_dst),a
        call try_pour
        jp c,deselect
        call push_undo
        ld hl,moves             ; ως 255
        ld a,(hl)
        inc a
        jr z,.hud
        ld (hl),a
.hud:   call hud_draw           ; κανένα σωματίδιο ακόμα στην οθόνη
        ld a,ST_POUR
        ld (state),a
        ret
.pour:  call particles_frame
        ret nz
        call pour_finish
        xor a
        ld (state),a
        call check_win
        jr nz,.stuck
        ld a,ST_WIN
        ld (state),a
        ld hl,str_win
        ld a,PEN_LIQUID+2
        jp hud_message
.stuck: call check_stuck
        ret nz
        ld hl,str_stuck
        ld a,PEN_LIQUID
        jp hud_message
.win:   ld a,(input_new)
        and IN_RESTART
        jp nz,level_start
        ld a,(input_new)
        and IN_FIRE
        ret z
        ld a,(level)            ; επόμενη πίστα (μετά την τελευταία: η 1η)
        inc a
        cp LEVEL_COUNT
        jr c,.next
        xor a
.next:  ld (level),a
        jp level_start

;------------------------------------------------------------------
; Undo: κάθε μετάγγιση γράφεται ως (πηγή, στόχος, στρώσεις).
push_undo:
        ld a,(undo_sp)
        cp UNDO_DEPTH
        jr c,.room
        ld hl,undo_stack+3      ; γεμάτο: χάνεται η παλαιότερη
        ld de,undo_stack
        ld bc,(UNDO_DEPTH-1)*3
        ldir
        ld a,UNDO_DEPTH-1
.room:  ld e,a
        inc a
        ld (undo_sp),a
        call undo_ptr
        ld a,(sel_src)
        ld (hl),a
        inc hl
        ld a,(sel_dst)
        ld (hl),a
        inc hl
        ld a,(pour_n)
        ld (hl),a
        ret

; HL = undo_stack + E*3
undo_ptr:
        ld l,e
        ld h,0
        ld d,h
        add hl,hl
        add hl,de
        ld de,undo_stack
        add hl,de
        ret

; Αναιρεί την τελευταία μετάγγιση, χωρίς πίδακα.
do_undo:
        ld a,(undo_left)
        or a
        ret z
        ld a,(undo_sp)
        or a
        ret z
        dec a
        ld (undo_sp),a
        ld e,a
        call undo_ptr
        ld a,(hl)
        ld (sel_src),a
        inc hl
        ld a,(hl)
        ld (sel_dst),a
        inc hl
        ld b,(hl)               ; στρώσεις
        call bottle_ix          ; A = στόχος
        push ix
        pop iy
        ld a,(sel_src)
        call bottle_ix
.layer: ld a,(iy+B_CNT)         ; κορυφή του στόχου -> πίσω στην πηγή
        dec a
        ld (iy+B_CNT),a
        add a,B_LAY
        ld e,a
        ld d,0
        push iy
        pop hl
        add hl,de
        ld c,(hl)
        ld a,(ix+B_CNT)
        add a,B_LAY
        ld e,a
        push ix
        pop hl
        add hl,de
        ld (hl),c
        inc (ix+B_CNT)
        djnz .layer
        call check_done
        call redraw_bottle
        push iy
        pop ix
        call check_done
        call redraw_bottle
        ld hl,undo_left
        dec (hl)
        ld hl,moves
        ld a,(hl)
        or a
        jr z,hud_draw
        dec (hl)
        jr hud_draw

;------------------------------------------------------------------
; HUD: πίστα, κινήσεις, undo που απομένουν.
hud_draw:
        call hud_clear
        ld hl,str_level
        ld bc,HUD_Y*256+1
        ld a,PEN_WHITE
        call print_str
        ld a,(level)
        inc a
        call num_str
        ld hl,num_buf+1
        ld bc,HUD_Y*256+13
        ld a,PEN_LIQUID+2
        call print_str
        ld hl,str_moves
        ld bc,HUD_Y*256+28
        ld a,PEN_WHITE
        call print_str
        ld a,(moves)
        call num_str
        ld hl,num_buf
        ld bc,HUD_Y*256+40
        ld a,PEN_LIQUID+2
        call print_str
        ld hl,str_undo
        ld bc,HUD_Y*256+58
        ld a,PEN_WHITE
        call print_str
        ld a,(undo_left)
        call num_str
        ld hl,num_buf+2
        ld bc,HUD_Y*256+68
        ld a,PEN_LIQUID+2
        jp print_str

hud_clear:
        ld a,HUD_Y
        ld c,0
        call scr_addr
        ld bc,10*256+80
        jp clear_rect

; Μήνυμα στη θέση του HUD, στο κέντρο. HL = κείμενο, A = pen.
hud_message:
        push af
        push hl
        call hud_clear
        pop hl
        push hl
        ld b,0
.len:   ld a,(hl)
        or a
        jr z,.x
        inc hl
        inc b
        jr .len
.x:     ld a,40                 ; x = (80 - 2*μήκος) / 2
        sub b
        ld c,a
        ld b,HUD_Y
        pop hl
        pop af
        jp print_str

; num_buf = A σε 3 ψηφία.
num_str:
        ld hl,num_buf
        ld c,100
        call .digit
        ld c,10
        call .digit
        add a,"0"
        ld (hl),a
        inc hl
        ld (hl),0
        ret
.digit: ld b,"0"-1
.sub:   inc b
        sub c
        jr nc,.sub
        add a,c
        ld (hl),b
        inc hl
        ret

;------------------------------------------------------------------
; out: Z = καμία έγκυρη μετάγγιση (αδιέξοδο).
check_stuck:
        ld a,(nbottles)
        ld b,a
        ld ix,bottles
.src:   ld a,(ix+B_CNT)
        or a
        jr z,.nsrc
        ld a,(ix+B_DONE)
        or a
        jr nz,.nsrc
        call top_layer
        ld c,(hl)               ; C = χρώμα της κορυφής
        push bc
        ld a,(nbottles)
        ld b,a
        ld iy,bottles
.dst:   push iy
        pop hl
        push ix
        pop de
        or a
        sbc hl,de
        jr z,.ndst              ; το ίδιο μπουκάλι
        ld a,(iy+B_CNT)
        cp (iy+B_CAP)
        jr z,.ndst              ; γεμάτο
        or a
        jr z,.found             ; άδειο
        add a,B_LAY-1
        ld e,a
        ld d,0
        push iy
        pop hl
        add hl,de
        ld a,(hl)
        cp c
        jr z,.found
.ndst:  ld de,BOT_SIZE
        add iy,de
        djnz .dst
        pop bc
.nsrc:  ld de,BOT_SIZE
        add ix,de
        djnz .src
        xor a
        ret
.found: pop bc
        or 1
        ret

deselect:
        ld a,(sel_src)
        call bottle_ix
        ld (ix+B_RAISE),0
        call redraw_bottle
        xor a
        ld (state),a
        ret

; out: Z = όλα τα μπουκάλια άδεια ή ολοκληρωμένα.
check_win:
        ld a,(nbottles)
        ld b,a
        ld ix,bottles
        ld de,BOT_SIZE
.bot:   ld a,(ix+B_CNT)
        or a
        jr z,.next
        ld a,(ix+B_DONE)
        or a
        jr nz,.next
        or 1
        ret
.next:  add ix,de
        djnz .bot
        xor a
        ret

; A = πλήκτρα κατεύθυνσης (input_new).
move_cursor:
        ld c,a
        push bc
        ld a,(cursor)
        call cursor_erase
        ld a,(cursor)
        call bottle_ix
        pop bc
        ld e,(ix+B_ROW)
        call row_info           ; B = αρχή, A = μήκος
        ld h,a
        ld a,(cursor)
        sub b
        ld d,a                  ; D = θέση στη σειρά
        bit 2,c                 ; IN_LEFT
        jr z,.right
        ld a,d
        or a
        jr nz,.l
        ld d,h
.l:     dec d
.right: bit 3,c                 ; IN_RIGHT
        jr z,.up
        inc d
        ld a,d
        cp h
        jr nz,.up
        ld d,0
.up:    bit 0,c                 ; IN_UP
        jr z,.down
        ld e,0
.down:  bit 1,c                 ; IN_DOWN
        jr z,.set
        ld a,(nrows)
        dec a
        jr z,.set
        ld e,1
.set:   call row_info
        dec a                   ; D = min(D, μήκος-1)
        cp d
        jr nc,.ok
        ld d,a
.ok:    ld a,b
        add a,d
        ld (cursor),a
        jp cursor_draw

; E = σειρά. out: B = πρώτο μπουκάλι, A = πλήθος. Κρατάει C, D, E, HL.
row_info:
        push hl
        ld hl,row_start
        ld a,e
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld b,(hl)
        ld hl,row_len
        ld a,e
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        pop hl
        ret

str_level:      db "LEVEL",0
str_moves:      db "MOVES",0
str_undo:       db "UNDO",0
str_win:        db "LEVEL CLEAR! SPACE",0
str_stuck:      db "NO MOVES! U UNDO  R RESTART",0
