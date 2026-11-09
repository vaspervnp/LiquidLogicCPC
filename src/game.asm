; game.asm — η λογική του παιχνιδιού: πίστες, επιλογή πηγής/στόχου,
; μετάγγιση, κινήσεις, undo, restart, αδιέξοδο, νίκη, ειδικοί τύποι
; (πάγος, λουκέτο, όριο κινήσεων, χρονόμετρο, έξτρα μπουκάλι)

ST_IDLE         equ 0           ; κέρσορας
ST_SEL          equ 1           ; πηγή επιλεγμένη (σηκωμένη)
ST_POUR         equ 2           ; ο πίδακας τρέχει
ST_WIN          equ 3
ST_FAIL         equ 4           ; τέλος χρόνου: μόνο R / SPACE

UNDO_MAX        equ 5           ; undo ανά πίστα
SNAP_SIZE       equ MAX_BOTTLES*BOT_SIZE+1      ; στιγμιότυπο: μπουκάλια + κινήσεις
HUD_Y           equ 3
KEY_E_LINE      equ 7           ; E: γραμμή 7, bit 2 του πληκτρολογίου
KEY_E_BIT       equ 4

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
        ld (extra_used),a
        ld (time_up),a
        ld (timer_on),a
        ld a,UNDO_MAX
        ld (undo_left),a
        ld a,(level_timer)      ; χρονόμετρο: header x 4 δευτερόλεπτα
        or a
        jr z,.notime
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld (time_left),hl
        ld a,50
        ld (time_frames),a
        ld (timer_on),a
.notime:
        call draw_all_bottles
        call hud_draw
        xor a
        jp cursor_draw

game_frame:
        ld a,(time_up)          ; τέλος χρόνου (αφού τελειώσει η μετάγγιση)
        or a
        jr z,.state
        ld a,(state)
        cp ST_POUR
        jr z,.state
        xor a
        ld (time_up),a
        ld (timer_on),a
        ld a,(state)
        or a
        call nz,deselect
        ld a,ST_FAIL
        ld (state),a
        ld hl,str_timeup
        ld a,PEN_LIQUID
        jp hud_message
.state: ld a,(state)
        cp ST_POUR
        jp z,.pour
        cp ST_WIN
        jp z,.win
        cp ST_FAIL
        jp z,.fail
        ld a,(input_new)
        and IN_RESTART
        jp nz,level_start
        ld a,(input_new)
        and IN_UNDO
        jr z,.extra
        ld a,(state)
        or a
        call nz,deselect
        jp do_undo
.extra: ld a,(keymap+KEY_E_LINE) ; E: έξτρα μπουκάλι
        cpl
        and KEY_E_BIT
        ld hl,key_e_prev
        ld b,(hl)
        ld (hl),a
        jr z,.move
        cp b
        jr z,.move
        ld a,(state)
        or a
        call nz,deselect
        jp extra_bottle
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
        ld a,(ix+B_DONE)        ; ολοκληρωμένο, παγωμένο, κλειδωμένο: όχι
        or (ix+B_FREEZE)
        or (ix+B_LOCK)
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
        call after_move
        xor a
        ld (state),a
        call check_win
        jr nz,.limit
        ld (timer_on),a         ; A = 0
        ld a,ST_WIN
        ld (state),a
        ld hl,str_win
        ld a,PEN_LIQUID+2
        jp hud_message
.limit: ld a,(level_moves)      ; όριο κινήσεων
        or a
        jr z,.stuck
        ld hl,moves
        cp (hl)
        jr z,.out
        jr nc,.stuck
.out:   ld hl,str_nomoves
        ld a,PEN_LIQUID
        jp hud_message
.stuck: call check_stuck
        ret nz
        ld hl,str_stuck
        call extra_allowed
        jr nz,.msg
        ld hl,str_stuck_e
.msg:   ld a,PEN_LIQUID
        jp hud_message
.fail:  ld a,(input_new)
        and IN_RESTART|IN_FIRE
        ret z
        jp level_start
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

; Μετά από κάθε μετάγγιση (τα σωματίδια έχουν σβηστεί): ξεκλείδωμα όσων
; περιμένουν το χρώμα που μόλις ολοκληρώθηκε, και ο πάγος μετράει μία κίνηση.
after_move:
        ld ix,(pour_dst)
        ld a,(ix+B_DONE)
        or a
        ld c,0
        jr z,.scan
        ld a,(ix+B_LAY)
        and #7F
        ld c,a                  ; C = χρώμα που ολοκληρώθηκε
.scan:  ld a,(nbottles)
        ld b,a
        ld ix,bottles
.bot:   push bc
        ld e,0                  ; E = χρειάζεται ξανασχεδίαση
        ld a,c
        or a
        jr z,.ice
        cp (ix+B_LOCK)
        jr nz,.ice
        ld (ix+B_LOCK),0
        inc e
.ice:   ld a,(ix+B_FREEZE)
        or a
        jr z,.draw
        dec (ix+B_FREEZE)
        inc e
.draw:  ld a,e
        or a
        call nz,redraw_bottle
        ld de,BOT_SIZE
        add ix,de
        pop bc
        djnz .bot
        ret

;------------------------------------------------------------------
; Undo: πριν από κάθε μετάγγιση (try_pour) ένα στιγμιότυπο όλων των
; μπουκαλιών και των κινήσεων· έτσι αναιρούνται και πάγος, λουκέτα,
; αποκαλύψεις και κουρτίνες. Κρατάει τα UNDO_MAX τελευταία.
push_undo:
        push ix
        push iy
        ld a,(undo_sp)
        cp UNDO_MAX
        jr c,.room
        ld hl,undo_stack+SNAP_SIZE      ; γεμάτο: χάνεται το παλαιότερο
        ld de,undo_stack
        ld bc,(UNDO_MAX-1)*SNAP_SIZE
        ldir
        ld a,UNDO_MAX-1
.room:  ld c,a
        inc a
        ld (undo_sp),a
        ld a,c
        call snap_ptr
        ex de,hl
        ld hl,bottles
        ld bc,MAX_BOTTLES*BOT_SIZE
        ldir
        ld a,(moves)
        ld (de),a
        pop iy
        pop ix
        ret

; HL = undo_stack + A * SNAP_SIZE
snap_ptr:
        ld hl,undo_stack
        or a
        ret z
        ld b,a
        ld de,SNAP_SIZE
.add:   add hl,de
        djnz .add
        ret

do_undo:
        ld a,(undo_left)
        or a
        ret z
        ld a,(undo_sp)
        or a
        ret z
        dec a
        ld (undo_sp),a
        call snap_ptr
        ld de,bottles
        ld bc,MAX_BOTTLES*BOT_SIZE
        ldir
        ld a,(hl)
        ld (moves),a
        ld hl,undo_left
        dec (hl)
        ld a,(nbottles)         ; κανένα σηκωμένο
        ld b,a
        ld ix,bottles
        ld de,BOT_SIZE
.low:   ld (ix+B_RAISE),0
        add ix,de
        djnz .low
        jp redraw_all

; Ολόκληρη η οθόνη από την αρχή.
redraw_all:
        call cls
        call draw_all_bottles
        call hud_draw
        ld a,(cursor)
        jp cursor_draw

;------------------------------------------------------------------
; NZ = το E επιτρέπεται σε αυτή την πίστα και δεν έχει χρησιμοποιηθεί.
extra_allowed:
        ld a,(level_flags)
        and LF_EXTRA
        ret z
        ld a,(extra_used)
        xor 1
        ret

; Ένα άδειο μπουκάλι παραπάνω (μία φορά ανά πίστα). Οι θέσεις αλλάζουν,
; οπότε τα στιγμιότυπα του undo δεν ισχύουν πια.
extra_bottle:
        call extra_allowed
        ret z
        ld a,(nbottles)
        cp MAX_BOTTLES
        ret nc
        ld a,1
        ld (extra_used),a
        ld a,(nbottles)
        push af
        inc a
        ld (nbottles),a
        pop af
        call bottle_ix
        ld a,(level_cap)
        call bottle_init
        ld (ix+B_FLAGS),0
        call layout
        xor a
        ld (undo_sp),a
        jp redraw_all

;------------------------------------------------------------------
; Χρονόμετρο: μέσα στο παράθυρο μετά το VSYNC (main.asm), όπου επιτρέπεται
; να γράφεται το HUD ενώ τρέχει πίδακας.
timer_tick:
        ld a,(timer_on)
        or a
        ret z
        ld hl,time_frames
        dec (hl)
        ret nz
        ld (hl),50
        ld hl,(time_left)
        ld a,h
        or l
        ret z
        dec hl
        ld (time_left),hl
        ld a,h
        or l
        jr nz,.show
        ld a,1
        ld (time_up),a
.show:  ld a,(hud_msg)
        or a
        ret nz
hud_time:
        ld hl,(time_left)
        call num16_str
        ld hl,num_buf
        ld bc,HUD_Y*256+60
        ld a,PEN_LIQUID+2
        jp print_str

;------------------------------------------------------------------
; HUD: πίστα, κινήσεις (ή όσες μένουν), undo, χρόνος, E+.
hud_draw:
        xor a
        ld (hud_msg),a
        call hud_clear
        ld hl,str_lv
        ld bc,HUD_Y*256+1
        ld a,PEN_WHITE
        call print_str
        ld a,(level)
        inc a
        call num_str
        ld hl,num_buf+1
        ld bc,HUD_Y*256+6
        ld a,PEN_LIQUID+2
        call print_str
        ld a,(level_moves)
        or a
        jr z,.moves
        ld hl,str_left          ; όριο: όσες μένουν
        ld bc,HUD_Y*256+14
        ld a,PEN_WHITE
        call print_str
        ld a,(moves)
        ld b,a
        ld a,(level_moves)
        sub b
        jr nc,.left
        xor a
.left:  call num_str
        ld bc,HUD_Y*256+24
        jr .mnum
.moves: ld hl,str_moves
        ld bc,HUD_Y*256+14
        ld a,PEN_WHITE
        call print_str
        ld a,(moves)
        call num_str
        ld bc,HUD_Y*256+26
.mnum:  ld hl,num_buf
        ld a,PEN_LIQUID+2
        call print_str
        ld hl,str_undo
        ld bc,HUD_Y*256+34
        ld a,PEN_WHITE
        call print_str
        ld a,(undo_left)
        call num_str
        ld hl,num_buf+2
        ld bc,HUD_Y*256+44
        ld a,PEN_LIQUID+2
        call print_str
        ld a,(level_timer)
        or a
        jr z,.extra
        ld hl,str_time
        ld bc,HUD_Y*256+50
        ld a,PEN_WHITE
        call print_str
        call hud_time
.extra: call extra_allowed
        ret z
        ld hl,str_extra
        ld bc,HUD_Y*256+74
        ld a,PEN_LIQUID+5       ; κυανό
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
        ld a,1
        ld (hud_msg),a
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
        ld l,a
        ld h,0
; num_buf = HL (ως 999) σε 3 ψηφία.
num16_str:
        ld de,num_buf
        ld bc,-100
        call .digit
        ld bc,-10
        call .digit
        ld a,l
        add a,"0"
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret
.digit: ld a,"0"-1
.sub:   inc a
        add hl,bc
        jr c,.sub
        sbc hl,bc
        ld (de),a
        inc de
        ret

;------------------------------------------------------------------
; out: Z = καμία έγκυρη μετάγγιση (αδιέξοδο). Παγωμένα και κλειδωμένα δεν
; μετράνε ούτε ως πηγή ούτε ως στόχος.
check_stuck:
        ld a,(nbottles)
        ld b,a
        ld ix,bottles
.src:   ld a,(ix+B_CNT)
        or a
        jr z,.nsrc
        ld a,(ix+B_DONE)
        or (ix+B_FREEZE)
        or (ix+B_LOCK)
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
        ld a,(iy+B_FREEZE)
        or (iy+B_LOCK)
        jr nz,.ndst
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

str_lv:         db "LV",0
str_moves:      db "MOVES",0
str_left:       db "LEFT",0
str_undo:       db "UNDO",0
str_time:       db "TIME",0
str_extra:      db "E+",0
str_win:        db "LEVEL CLEAR! SPACE",0
str_stuck:      db "NO MOVES! U UNDO  R RESTART",0
str_stuck_e:    db "NO MOVES! E EXTRA BOTTLE",0
str_nomoves:    db "OUT OF MOVES! U UNDO  R RESTART",0
str_timeup:     db "TIME UP! R RESTART",0
