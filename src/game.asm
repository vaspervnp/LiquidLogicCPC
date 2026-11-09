; game.asm — κέρσορας, επιλογή πηγής/στόχου, μετάγγιση, νίκη (demo του M1)

ST_IDLE         equ 0           ; κέρσορας
ST_SEL          equ 1           ; πηγή επιλεγμένη (σηκωμένη)
ST_POUR         equ 2           ; ο πίδακας τρέχει
ST_WIN          equ 3

game_init:
        call cls
        ld hl,str_title
        ld bc,3*256+2
        ld a,PEN_WHITE
        call print_str
        ld hl,demo_level
        call level_setup
        call draw_all_bottles
        xor a
        ld (cursor),a
        ld (state),a
        jp cursor_draw

game_frame:
        ld a,(state)
        cp ST_POUR
        jp z,.pour
        cp ST_WIN
        jp z,.win
        ld a,(input_new)
        and IN_RESTART
        jp nz,game_init
        ld a,(input_new)
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
        ld a,ST_POUR
        ld (state),a
        ret
.pour:  call particles_frame
        ret nz
        call pour_finish
        xor a
        ld (state),a
        call check_win
        ret nz
        ld a,ST_WIN
        ld (state),a
        ld hl,str_win
        ld bc,3*256+50
        ld a,PEN_LIQUID+2
        jp print_str
.win:   ld a,(input_new)
        and IN_FIRE|IN_RESTART
        ret z
        jp game_init

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

str_title:      db "LIQUID LOGIC",0
str_win:        db "WELL DONE!",0

; Δοκιμαστική διάταξη: 9 μπουκάλια x 4, 7 χρώματα, 2 άδεια.
demo_level:
        db 9,4
        db 4, 4,5,6,7
        db 4, 8,9,10,4
        db 4, 5,6,7,8
        db 4, 9,10,4,5
        db 4, 6,7,8,9
        db 4, 10,4,5,6
        db 4, 7,8,9,10
        db 0
        db 0
