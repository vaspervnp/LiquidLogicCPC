; main.asm — Liquid Logic, M2: πίστες, κινήσεις, undo, αδιέξοδο, νίκη
;
; Βελάκια/joystick = κέρσορας, SPACE = επιλογή του μπουκαλιού από το οποίο
; αδειάζει (σηκώνεται) και μετά εκείνου στο οποίο γεμίζει. Το υγρό πετάγεται
; σαν πίδακας σωματιδίων με βαρύτητα (particles.asm). ESC = ακύρωση,
; U = undo, R = η πίστα από την αρχή.
;
; Memory map (RAM config C0, firmware εκτός, DI):
;   #0000-#003F  vectors (EI:RET στο #38, για ασφάλεια)
;   #0100-#03FF  particles, MAX_PART x P_SIZE
;   #0500-#06FF  line_lo, line_hi: διευθύνσεις των 200 γραμμών
;   #0700-#08FF  δύο λίστες σχεδίασης των particles, MAX_PART x L_SIZE
;   #0900-#0FFF  stack (από το #1000 προς τα κάτω)
;   #1000-       κώδικας + δεδομένα
;   #C000-#FFFF  οθόνη

        org #1000
        run start

STACK_TOP       equ #1000
particles       equ #0100
line_lo         equ #0500
line_hi         equ #0600
dlist_a         equ #0700
dlist_b         equ #0800

start:
        di
        ld sp,STACK_TOP
        im 1
        ld hl,#C9FB             ; EI : RET
        ld (#38),hl
        ld bc,#7F00+GA_RAM_C0
        out (c),c
        ld bc,#7F00+GA_MODE0
        out (c),c
        call set_palette
        call make_line_table
        ld a,r                  ; seed (≠ 0)
        or 1
        ld (rnd_seed),a
        call game_start

; Μετά το VSYNC η δέσμη χρειάζεται ~4,6 ms ως την πρώτη γραμμή της εικόνας:
; εκεί χωράει το σβήσιμο/σχεδίαση των particles (particles.asm).
main_loop:
        call wait_vsync
        call part_erase
        call liquid_sync
        call part_draw
        call read_input
        call game_frame
        jr main_loop

        include "hw.asm"
        include "screen.asm"
        include "bottles.asm"
        include "particles.asm"
        include "pour.asm"
        include "game.asm"
        include "gfx.asm"
        include "physics.asm"
        include "levels.asm"

;------------------------------------------------------------------
; Μεταβλητές
rnd_seed:       dw #ACE1
keymap:         ds 10
input:          db 0
input_new:      db 0
txt_pen:        db 0
row_n:          db 0
tmp_row:        db 0
tmp_y:          db 0
tmp_x0:         db 0
tmp_ys:         db 0
tmp_t:          db 0

level:          db 0            ; πίστα (από 0)
moves:          db 0
undo_left:      db 0
undo_sp:        db 0
undo_stack:     ds UNDO_DEPTH*3
num_buf:        ds 4
level_flags:    db 0            ; header της πίστας (level_setup)
level_moves:    db 0            ; με αυτή τη σειρά
level_timer:    db 0
level_par:      db 0

nbottles:       db 0
level_cap:      db 0
nrows:          db 0
row_start:      db 0,0
row_len:        db 0,0
bottles:        ds MAX_BOTTLES*BOT_SIZE

state:          db 0
cursor:         db 0
sel_src:        db 0
sel_dst:        db 0

pour_src:       dw 0            ; IX των δύο μπουκαλιών
pour_dst:       dw 0
pour_pen:       db 0
pour_pl:        db 0            ; pen_left / pen_right του pour_pen
pour_pr:        db 0
pour_space:     db 0
pour_n:         db 0
src_lines:      db 0            ; γραμμές υγρού στην οθόνη
src_final:      db 0
src_acc:        db 0
dst_lines:      db 0
dst_target:     db 0
dst_acc:        db 0
dst_add:        db 0
dst_thresh:     db 0
dst_bottom:     db 0            ; γραμμή οθόνης του πάτου του υγρού στο B
dst_surf:       db 0
dst_entry:      db 0
clear_y:        db 0            ; οριζόντια κίνηση στην πτήση μόνο για y < clear_y
dst_xl:         db 0            ; εσωτερικό του σώματος (pixels)
dst_xr:         db 0
dst_nl:         db 0            ; εσωτερικό του λαιμού
dst_nr:         db 0
emit_left:      dw 0
emit_x:         dw 0
emit_y:         dw 0
base_vx:        dw 0
base_vy:        dw 0
p_alive:        db 0
src_shown:      db 0            ; γραμμές υγρού που φαίνονται
dst_shown:      db 0
dlist:          dw dlist_a      ; σχεδιασμένη λίστα (για σβήσιμο)
dlist_end:      dw dlist_a
dlist_n:        db 0
plist:          dw dlist_b      ; εκκρεμής λίστα (για σχεδίαση)
plist_end:      dw dlist_b
plist_n:        db 0

code_end:
        assert code_end <= #A000, "code overflows BASIC HIMEM"
        assert particles+MAX_PART*P_SIZE <= line_lo, "particles overlap line_lo"
        assert MAX_PART*L_SIZE <= 256, "draw list larger than a page"
        assert dlist_b+256 <= STACK_TOP-#600, "draw lists overlap the stack"

; Το rasm γράφει το αρχείο κατευθείαν σε Extended DSK, με AMSDOS header
; (load = exec = #1000).
        save "LIQUID.BIN",#1000,code_end-#1000,DSK,"build/LiquidLogic.dsk"
