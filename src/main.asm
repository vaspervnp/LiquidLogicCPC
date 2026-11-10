; main.asm — Liquid Logic
;
; Βελάκια/joystick = κέρσορας, SPACE = επιλογή του μπουκαλιού από το οποίο
; αδειάζει (σηκώνεται) και μετά εκείνου στο οποίο γεμίζει. Το υγρό πετάγεται
; σαν πίδακας σωματιδίων με βαρύτητα (particles.asm). ESC = ακύρωση,
; U = undo, R = η πίστα από την αρχή.
;
; Memory map (RAM config C0, firmware εκτός· interrupts μόνο για τον ήχο):
;   #0000-#003F  vectors (IM 1: JP int_handler στο #38, ο ήχος)
;   #0100-#03FF  particles, MAX_PART x P_SIZE
;   #0500-#06FF  line_lo, line_hi: διευθύνσεις των 200 γραμμών
;   #0700-#0FFF  stack (από το #1000 προς τα κάτω)
;   #1000-#3FFF  κώδικας + δεδομένα
;   #4000-#7FFF  παράθυρο του bank 4 (RAM config C4), μόνο στο level_load:
;                οι 100 πίστες (LEVELS.BIN, το φορτώνει το DISC.BAS)
;   #8000-#A6FF  buffers χωρίς αρχική τιμή (BSS: λίστες σχεδίασης, undo, μπουκάλια...)
;   #C000-#FFFF  οθόνη

        org #1000
        run start

STACK_TOP       equ #1000
particles       equ #0100
line_lo         equ #0500
line_hi         equ #0600

; Buffers χωρίς αρχική τιμή, στο #8000-#A6FF: πάντα ορατό (και με το bank 4
; στο #4000), κάτω από το workspace του AMSDOS (KL INIT BACK ως το #ABFF).
BSS             equ #8000
dlist_a         equ BSS             ; δύο λίστες σχεδίασης των particles
dlist_b         equ BSS+#200
undo_stack      equ BSS+#400        ; UNDO_MAX στιγμιότυπα
level_buf       equ undo_stack+UNDO_MAX*SNAP_SIZE   ; η τρέχουσα πίστα, από το bank 4
bottles         equ level_buf+LEVEL_MAX
fw_low          equ bottles+MAX_BOTTLES*BOT_SIZE    ; #0000-#003F του firmware
keymap          equ fw_low+64
mus_a           equ keymap+10       ; μελωδία, και αμέσως μετά
mus_c           equ mus_a+MC_SIZE   ; το μπάσο
big_row         equ mus_c+MC_SIZE
num_buf         equ big_row+4
relax_cols      equ num_buf+4
relax_pool      equ relax_cols+12
fly_buf_a       equ relax_pool+32   ; φόντο κάτω από την πηγή στην πτήση
fly_buf_b       equ fly_buf_a+FLY_SIZE
fly_strip       equ fly_buf_b+FLY_SIZE  ; οι 2 στήλες του γερσίματος
BSS_END         equ fly_strip+2*BOTTLE_H

start:
        di
        ld hl,0                 ; τα vectors του firmware, για το disc.asm
        ld de,fw_low
        ld bc,64
        ldir
        ei
        call load_progress      ; με το firmware ακόμα ενεργό
        di
        ld sp,STACK_TOP
        im 1
        ld a,#C3                ; JP int_handler στο #38 (sound.asm)
        ld (#38),a
        ld hl,int_handler
        ld (#39),hl
        ld bc,#7F00+GA_RAM_C0
        out (c),c
        ld bc,#7F00+GA_MODE0
        out (c),c
        call set_palette
        call make_line_table
        call sound_init
        ld a,r                  ; seed (≠ 0)
        or 1
        ld (rnd_seed),a
        ei                      ; από εδώ ο ήχος παίζει από το interrupt
        call title_start

; Μετά το VSYNC η δέσμη χρειάζεται ~4,6 ms ως την πρώτη γραμμή της εικόνας:
; εκεί χωράει το σβήσιμο/σχεδίαση των particles (particles.asm).
main_loop:
        call wait_vsync
        ld hl,frames_main
        inc (hl)
        call part_erase
        call liquid_sync
        call timer_tick
        call part_draw
        call read_input
        call mode_frame
        jr main_loop

        include "hw.asm"
        include "screen.asm"
        include "bottles.asm"
        include "particles.asm"
        include "pour.asm"
        include "game.asm"
        include "relax.asm"
        include "ui.asm"
        include "sound.asm"
        include "disc.asm"
        include "gfx.asm"
        include "physics.asm"
        include "sound_data.asm"

;------------------------------------------------------------------
; Μεταβλητές
rnd_seed:       dw #ACE1
input:          db 0            ; IN_*, με αυτή τη σειρά
input_new:      db 0
input2:         db 0            ; IN2_*, με αυτή τη σειρά
input2_new:     db 0
txt_pen:        db 0
tmp_pen:        db 0
row_n:          db 0
tmp_row:        db 0
tmp_y:          db 0
tmp_x0:         db 0
tmp_ys:         db 0
tmp_t:          db 0

sfx_ptr:        dw 0            ; ήχος (sound.asm)
sfx_vol:        db 0
plip_per:       dw 0
plip_vol:       db 0
music_on:       db 0
snd_frame:      db 0
int_idx:        db 0            ; interrupt μετά το VSYNC (0-5)
frames_int:     db 0            ; καρέ: από το interrupt του VSYNC
frames_main:    db 0            ; γύροι του κύριου βρόχου (διαφορά = late frames)
mode:           db 0            ; MODE_*: τίτλος, επιλογή, παιχνίδι
sel_level:      db 0
unlocked:       db 1            ; πόσες πίστες παίζονται      } LIQUID.SAV,
stars:          ds MAX_LEVELS   ; καλύτερα αστέρια ανά πίστα  } συνεχόμενα
fw_sp:          dw 0
save_dirty:     db 0            ; 1 = η πρόοδος άλλαξε (award_stars)
tmp_stars:      db 0
paused_timer:   db 0
level:          db 0            ; πίστα (από 0)
relax:          db 0            ; 1 = «Χαλάρωση»: τυχαίες πίστες (relax.asm)
relax_new:      db 0            ; 1 = το level_start φτιάχνει καινούργια
relax_ncol:     db 0
moves:          db 0
undo_left:      db 0
undo_sp:        db 0
undo_ptr:       dw 0
tilt_row:       db 0
extra_used:     db 0
hud_msg:        db 0            ; 1 = μήνυμα στη θέση του HUD
timer_on:       db 0
time_up:        db 0
time_frames:    db 0
time_left:      dw 0            ; δευτερόλεπτα
level_flags:    db 0            ; header της πίστας (level_setup)
level_moves:    db 0            ; με αυτή τη σειρά
level_timer:    db 0
level_par:      db 0

nbottles:       db 0
level_cap:      db 0
nrows:          db 0
row_start:      db 0,0
row_len:        db 0,0

state:          db 0
shake_cnt:      db 0            ; καρέ που μένουν στο χοροπηδητό
shake_bot:      db 0
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
pour_phase:     db 0            ; 0 πτήση ως τον στόχο, 1 πίδακας, 2 επιστροφή
hover_x:        db 0            ; δίπλα στον στόχο (x, y με αυτή τη σειρά)
hover_y:        db 0
hover_tilt:     db 0
home_x:         db 0            ; η θέση της πηγής (x, y με αυτή τη σειρά)
home_y:         db 0
fly_x:          db 0            ; τρέχουσα θέση στην πτήση (x, y)
fly_y:          db 0
fly_nx:         db 0            ; νέα θέση (x, y)
fly_ny:         db 0
fly_ddx:        db 0
fly_ddy:        db 0
fly_ow:         db 0            ; επικάλυψη παλιάς/νέας θέσης
fly_oh:         db 0
fly_ro0:        db 0
fly_ps:         db 0
fly_cnt:        db 0
fly_ax:         dw 0            ; 8.8
fly_ay:         dw 0
fly_sx:         dw 0
fly_sy:         dw 0
fly_old:        dw 0            ; buffers φόντου: τρέχουσα / νέα θέση
fly_new:        dw 0
strip_x:        db 0
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
dlist_n:        db 0
plist:          dw dlist_b      ; εκκρεμής λίστα (για σχεδίαση)
plist_end:      dw dlist_b
plist_n:        db 0
upd_left:       db 0            ; part_update
cur_st:         db 0
cur_vyh:        db 0
sp_save:        dw 0            ; xor_list
bc_save:        dw 0

code_end:
        assert code_end <= #4000, "code overflows into the bank window"
        assert particles+MAX_PART*P_SIZE <= line_lo, "particles overlap line_lo"
        assert MAX_PART*L_SIZE <= #200, "draw list too long"
        assert BSS_END <= #A600, "BSS overlaps the AMSDOS workspace"

; Το rasm γράφει το αρχείο κατευθείαν σε Extended DSK, με AMSDOS header
; (load = exec = #1000).
        save "LIQUID.BIN",#1000,code_end-#1000,DSK,"build/LiquidLogic.dsk"

;------------------------------------------------------------------
; Bank 4 (C4, στο #4000-#7FFF): οι πίστες. level_table πρώτο, στο #4000.
;------------------------------------------------------------------

        bank 4
        org #4000
levels_data:
        include "levels.asm"
levels_end:

        assert levels_end <= #8000, "bank 4 is full"
        assert LEVEL_COUNT <= MAX_LEVELS, "too many levels"
        save "LEVELS.BIN",levels_data,levels_end-levels_data,DSK,"build/LiquidLogic.dsk"
