; pour.asm — μετάγγιση: κανόνες, ενημέρωση στρώσεων, τροχιά του πίδακα

APEX_H          equ 6           ; η κορυφή του τόξου, πάνω από το ψηλότερο στόμιο
HOVER_DY        equ 12          ; η πηγή, δίπλα στον στόχο: τόσο πιο ψηλά
FLY_N           equ 8           ; βήματα της πτήσης (πήγαινε, έλα· ~2 καρέ το καθένα)
FLY_SIZE        equ BOTTLE_W*BOTTLE_H
MOUTH_X         equ 7           ; στόμιο: pixel μέσα στο μπουκάλι
SRC_MOUTH_DY    equ -2          ; εκπομπή λίγο πάνω από το χείλος του A
DST_MOUTH_DY    equ 3           ; είσοδος στο λαιμό του B

; HL = διεύθυνση της επάνω στρώσης του μπουκαλιού IX (B_CNT > 0).
top_layer:
        ld a,(ix+B_CNT)
        dec a
        add a,B_LAY
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de
        ret

; Ξεκινάει τη μετάγγιση sel_src -> sel_dst. out: C = άκυρη.
try_pour:
        ld a,(sel_dst)
        call bottle_ix
        ld (pour_dst),ix
        ld a,(sel_src)
        call bottle_ix
        ld (pour_src),ix
        ld iy,(pour_dst)
        ; κανόνες (plan.md §1, §3)
        ld a,(level_moves)      ; όριο κινήσεων
        or a
        jr z,.nolim
        ld hl,moves
        cp (hl)
        jp z,.fail
        jp c,.fail
.nolim: ld a,(ix+B_CNT)
        or a
        jp z,.fail
        ld a,(iy+B_DONE)
        or a
        jp nz,.fail
        ld a,(iy+B_FREEZE)      ; παγωμένος / κλειδωμένος στόχος
        or (iy+B_LOCK)
        jp nz,.fail
        ld a,(iy+B_CAP)
        sub (iy+B_CNT)
        jp z,.fail
        ld (pour_space),a
        call top_layer
        ld a,(hl)
        and #7F
        ld (pour_pen),a
        ld a,(iy+B_CNT)
        or a
        jr z,.ok
        push ix
        push iy
        pop ix
        call top_layer
        pop ix
        ld a,(pour_pen)
        cp (hl)
        jp nz,.fail
.ok:    call top_layer          ; πόσες ίδιες στη σειρά από την κορυφή του A
        ld b,(ix+B_CNT)
        ld c,0
        ld a,(pour_pen)
.run:   cp (hl)
        jr nz,.rund
        inc c
        dec hl
        djnz .run
.rund:  bit BFB_DROPPER,(ix+B_FLAGS)
        jr z,.drop
        ld c,1                  ; σταγονόμετρο: μία στρώση τη φορά
.drop:  ld a,(pour_space)       ; n = min(run, χώρος)
        cp c
        jr nc,.n
        ld c,a
.n:     ld a,c
        ld (pour_n),a

        call push_undo          ; η κατάσταση πριν από τη μετάγγιση
        call uncurtain          ; η κουρτίνα φεύγει από πηγή και στόχο
        push ix
        push iy
        pop ix
        call uncurtain
        pop ix
        ; η πηγή πετάει δίπλα στον στόχο, από την πλευρά απ' όπου έρχεται
        ; (αν χωράει), με το στόμιο HOVER_DY γραμμές πιο ψηλά, και γέρνει προς
        ; αυτόν. Στη θέση του διπλανού μπουκαλιού (βήμα BOTTLE_PITCH): το
        ; γέρσιμο (ως 2 bytes) μένει στο κενό, έξω από τον στόχο.
        ld a,(iy+B_X)
        cp (ix+B_X)
        jr c,.right
        sub BOTTLE_PITCH        ; αριστερά
        jr c,.r
.l:     ld b,1
        jr .hov
.right: ld a,(iy+B_X)
        cp 80-BOTTLE_W-BOTTLE_PITCH+1
        jr c,.r
        sub BOTTLE_PITCH
        jr .l
.r:     ld a,(iy+B_X)           ; δεξιά
        add a,BOTTLE_PITCH
        ld b,-1
.hov:   ld (hover_x),a
        ld a,b
        ld (hover_tilt),a
        ld a,(iy+B_Y)
        sub HOVER_DY
        ld (hover_y),a
        ld a,(ix+B_X)           ; από τη θέση του, σηκωμένο: από κάτω φόντο
        ld (home_x),a
        ld (fly_x),a
        ld a,(ix+B_Y)
        ld (home_y),a
        sub (ix+B_RAISE)
        ld (ix+B_Y),a
        ld (fly_y),a
        ld (ix+B_RAISE),0
        ld hl,fly_buf_a
        ld (fly_old),hl
        ld (hl),0
        ld de,fly_buf_a+1
        ld bc,FLY_SIZE-1
        ldir
        ld hl,fly_buf_b
        ld (fly_new),hl
        ld bc,(hover_x)
        call fly_start
        xor a
        ld (pour_phase),a

        ; γραμμές οθόνης πριν
        ld a,(ix+B_CNT)
        ld e,(ix+B_LH)
        call mul8
        ld (src_lines),a
        ld a,(iy+B_CNT)
        ld e,(iy+B_LH)
        call mul8
        ld (dst_lines),a
        ld (dst_shown),a
        ld a,(src_lines)
        ld (src_shown),a

        ; λογική: n στρώσεις από το A στο B
        ld a,(pour_n)
        ld b,a
.move:  ld a,(iy+B_CNT)
        add a,B_LAY
        ld e,a
        ld d,0
        push iy
        pop hl
        add hl,de
        ld a,(pour_pen)
        ld (hl),a
        inc (iy+B_CNT)
        dec (ix+B_CNT)
        djnz .move
        ld a,(ix+B_CNT)         ; η νέα κορυφή της πηγής αποκαλύπτεται (φαίνεται
        or a                    ; όταν ξανασχεδιαστεί, στο pour_finish)
        jr z,.reveal
        call top_layer
        res 7,(hl)
.reveal:

        ; γραμμές οθόνης μετά
        ld a,(ix+B_CNT)
        ld e,(ix+B_LH)
        call mul8
        ld (src_final),a
        ld a,(iy+B_CNT)
        ld e,(iy+B_LH)
        call mul8
        ld (dst_target),a

        ; σωματίδια: n * lhA * PPL, ανά dst_thresh = lhA*PPL μια γραμμή του B
        ld a,(ix+B_LH)
        add a,a                 ; PPL = 2
        ld (dst_thresh),a
        ld e,a
        ld a,(pour_n)
        call mul8
        ld l,a
        ld h,0
        ld (emit_left),hl
        ld a,(iy+B_LH)
        ld (dst_add),a
        xor a
        ld (src_acc),a
        ld (dst_acc),a

        ; όρια του B
        ld a,(iy+B_X)
        add a,a
        ld b,a                  ; B = x του B σε pixels
        add a,2
        ld (dst_xl),a
        add a,11
        ld (dst_xr),a
        ld a,b
        add a,5
        ld (dst_nl),a
        add a,5
        ld (dst_nr),a
        ld a,(iy+B_Y)
        add a,BODY_BOTTOM
        ld (dst_bottom),a
        call set_dst_surf

        ; pens του πίδακα
        ld a,(pour_pen)
        ld e,a
        ld d,0
        ld hl,pen_left
        add hl,de
        ld a,(hl)
        ld (pour_pl),a
        ld hl,pen_right
        add hl,de
        ld a,(hl)
        ld (pour_pr),a
        call part_clear
        or a                    ; NC = εντάξει
        ret
.fail:  scf
        ret

; Η πηγή έφτασε δίπλα στον στόχο: γέρνει, και η τροχιά του πίδακα.
pour_aim:
        ld ix,(pour_src)
        ld iy,(pour_dst)
        ld a,(hover_tilt)
        ld (ix+B_TILT),a
        ld c,(ix+B_X)           ; οι 2 στήλες προς τον στόχο, που τις πιάνει
        dec c                   ; το γέρσιμο: φυλάγονται
        dec c
        or a
        jp m,.strip
        ld a,c
        add a,BOTTLE_W+2
        ld c,a
.strip: ld a,c
        ld (strip_x),a
        ld a,(ix+B_Y)
        call scr_addr
        ld de,fly_strip
        ld b,BOTTLE_H
.sv:    push bc
        push hl
        ldi
        ldi
        pop hl
        NEXT_LINE
        pop bc
        djnz .sv
        call draw_bottle
        call unshear

        ; τροχιά: κορυφή APEX_H πάνω από το ψηλότερο στόμιο
        ld a,(ix+B_Y)
        sub (ix+B_RAISE)
        add a,SRC_MOUTH_DY
        ld (tmp_ys),a
        ld a,(iy+B_Y)
        add a,DST_MOUTH_DY
        ld (dst_entry),a
        ld hl,tmp_ys            ; apex = min(ys, yd) - APEX_H
        cp (hl)
        jr c,.min
        ld a,(hl)
.min:   sub APEX_H
        ld c,a                  ; C = apex
        ld a,255                ; δίπλα στον στόχο: χωρίς ζώνη (clear_y)
        ld (clear_y),a
        ld b,a
        ; T = χρόνος μέσα στη ζώνη = t(min(ys,clear) - apex) + t(min(yd,clear) - apex)
        ld a,(dst_entry)
        cp b
        jr c,.yd
        ld a,b
.yd:    sub c
        ld e,a
        ld d,0
        ld hl,phys_t
        add hl,de
        ld a,(hl)
        ld (tmp_t),a
        ld a,(tmp_ys)
        cp b
        jr c,.ys
        ld a,b
.ys:    sub c
        ld e,a
        ld hl,phys_t
        add hl,de
        ld a,(tmp_t)
        add a,(hl)
        cp 128
        jr c,.t
        ld a,127
.t:     ld (tmp_t),a
        ld a,(tmp_ys)           ; vy0 = -v(ys - apex)
        sub c
        ld e,a
        ld hl,phys_v
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        xor a
        ld h,a
        ld l,a
        sbc hl,de
        ld (base_vy),hl
        ld a,(tmp_ys)
        ld h,a
        ld l,0
        ld (emit_y),hl
        ; vx = dx * (65536/T) / 256
        ld a,(ix+B_TILT)        ; το στόμιο, μετατοπισμένο από το γέρσιμο (x4 pixels)
        add a,a
        add a,a
        ld c,a
        ld a,(ix+B_X)
        add a,a
        add a,MOUTH_X
        add a,c
        ld h,a
        ld l,#80
        ld (emit_x),hl
        ld c,a                  ; C = xs
        ld a,(iy+B_X)
        add a,a
        add a,MOUTH_X
        sub c                   ; A = dx
        push af
        jr nc,.abs
        neg
.abs:   push af
        ld a,(tmp_t)
        ld l,a
        ld h,0
        add hl,hl
        ld de,phys_recip
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop af
        call mul8x16            ; C:HL = |dx| * recip
        ld l,h
        ld h,c
        pop af
        jr nc,.vx
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.vx:    ld (base_vx),hl
        ret

; Βγάζει την κουρτίνα του IX (και το ξανασχεδιάζει).
uncurtain:
        bit BFB_CURTAIN,(ix+B_FLAGS)
        ret z
        res BFB_CURTAIN,(ix+B_FLAGS)
        jp redraw_bottle

; Τέλος: όσες γραμμές δεν έφτασαν (σωματίδια που χάθηκαν), κατέβασμα του A,
; φελλός στο B αν ολοκληρώθηκε.
pour_finish:
        call part_erase         ; ό,τι σχεδιάστηκε σε αυτό το καρέ
        ld a,(dst_target)
        ld (dst_lines),a
        ld a,(src_final)
        ld (src_lines),a
        call liquid_sync
        ld ix,(pour_src)        ; όρθιο ξανά, και πίσω στη θέση του
        ld (ix+B_TILT),0
        call draw_bottle        ; (και η νέα κορυφή του, αν ήταν κρυμμένη)
        ld a,(strip_x)          ; οι 2 στήλες προς τον στόχο, όπως ήταν
        ld c,a
        ld a,(ix+B_Y)
        call scr_addr
        ex de,hl
        ld hl,fly_strip
        ld b,BOTTLE_H
.st:    push bc
        push de
        ldi
        ldi
        pop de
        ex de,hl
        NEXT_LINE
        ex de,hl
        pop bc
        djnz .st
        ld bc,(home_x)
        call fly_start
        ld ix,(pour_dst)
        call check_done
        ld a,(ix+B_DONE)
        or a
        ret z
        ld hl,sfx_cork          ; φελλός
        call play_sfx
        jp draw_bottle


;------------------------------------------------------------------
; Πτήση της πηγής (όρθιας) σε FLY_N καρέ, σε ευθεία, με 8.8 βήματα.
; in: C = x, B = y προορισμού· από (fly_x, fly_y).
fly_start:
        ld a,(opt_speed)        ; γρήγορη: μισά βήματα, διπλά μεγάλα
        or a
        ld a,FLY_N
        jr z,.n
        ld a,FLY_N/2
.n:     ld (fly_cnt),a
        ld a,(fly_x)
        ld h,a
        ld l,#80
        ld (fly_ax),hl
        ld a,c
        sub h
        call .step
        ld (fly_sx),hl
        ld a,(fly_y)
        ld h,a
        ld l,#80
        ld (fly_ay),hl
        ld a,b
        sub h
        call .step
        ld (fly_sy),hl
        ret
.step:  ld l,a                  ; HL = A (με πρόσημο) * 256 / FLY_N
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(opt_speed)
        or a
        ret z
        add hl,hl
        ret
        assert FLY_N == 8

; Ένα καρέ της πτήσης. out: Z = έφτασε.
fly_step:
        ld ix,(pour_src)
        ld hl,(fly_ax)
        ld de,(fly_sx)
        add hl,de
        ld (fly_ax),hl
        ld c,h
        ld hl,(fly_ay)
        ld de,(fly_sy)
        add hl,de
        ld (fly_ay),hl
        ld b,h
        call fly_move
        ld hl,fly_cnt
        dec (hl)
        ret

; Το μπουκάλι IX (όρθιο, BOTTLE_W x BOTTLE_H) από το (fly_x, fly_y) στο
; (C, B), χωρίς τρεμόπαιγμα: το φόντο κάτω από τη νέα θέση φυλάγεται στο
; fly_new (από την οθόνη, και όπου επικαλύπτεται με την παλιά, από το
; fly_old), το μπουκάλι σχεδιάζεται, και μόνο μετά επανέρχεται ό,τι
; ξεσκεπάστηκε από την παλιά θέση.
fly_move:
        ld (fly_nx),bc          ; fly_nx = C, fly_ny = B
        ld a,c
        ld hl,fly_x
        sub (hl)
        ld (fly_ddx),a          ; dx = νέο - παλιό
        ld a,b
        ld hl,fly_y
        sub (hl)
        ld (fly_ddy),a          ; dy
        ; οθόνη -> fly_new
        ld a,b
        call scr_addr
        ld de,(fly_new)
        ld b,BOTTLE_H
.save:  push bc
        push hl
        ld bc,BOTTLE_W
        ldir
        pop hl
        NEXT_LINE
        pop bc
        djnz .save
        ; επικάλυψη: w = W - |dx|, h = H - |dy| (fly_oh = 0: καμία)
        xor a
        ld (fly_oh),a
        ld a,(fly_ddx)
        call abs_a
        cp BOTTLE_W
        jr nc,.draw
        neg
        add a,BOTTLE_W
        ld (fly_ow),a
        ld a,(fly_ddy)
        call abs_a
        cp BOTTLE_H
        jr nc,.draw
        neg
        add a,BOTTLE_H
        ld (fly_oh),a
        ; fly_old + ro0*W + co0 -> fly_new + rn0*W + cn0, με ro0 = max(0, dy),
        ; rn0 = max(0, -dy) (και το ίδιο για τις στήλες)
        ld a,(fly_ddy)
        call split              ; A = ro0, C = rn0
        ld (fly_ro0),a
        call times_w
        ld de,(fly_old)
        add hl,de
        push hl
        ld a,c
        call times_w
        ld de,(fly_new)
        add hl,de
        push hl
        ld a,(fly_ddx)
        call split              ; A = co0, C = cn0
        pop hl
        ld e,c
        ld d,0
        add hl,de
        ex de,hl                ; DE = fly_new + ...
        pop hl
        ld c,a
        ld b,0
        add hl,bc               ; HL = fly_old + ...
        ld a,(fly_oh)
        ld b,a
.lap:   push bc
        push hl
        push de
        ld a,(fly_ow)
        ld c,a
        ld b,0
        ldir
        pop hl
        ld bc,BOTTLE_W
        add hl,bc
        ex de,hl
        pop hl
        add hl,bc
        pop bc
        djnz .lap
.draw:  ld a,(fly_nx)
        ld (ix+B_X),a
        ld a,(fly_ny)
        ld (ix+B_Y),a
        call draw_bottle
        ; fly_old -> οθόνη, μόνο όσα δεν σκεπάζει η νέα θέση: στις γραμμές
        ; της επικάλυψης οι |dx| στήλες της πλευράς απ' όπου έφυγε
        ld a,(fly_ddx)
        or a
        ld a,0
        jp m,.neg
        ld (fly_ps),a           ; dx >= 0: από τη στήλη 0
        jr .ps
.neg:   ld a,(fly_ow)           ; dx < 0: από τη στήλη w
        ld (fly_ps),a
.ps:    ld a,(fly_x)
        ld c,a
        ld a,(fly_y)
        call scr_addr
        ld de,(fly_old)
        ld b,0                  ; γραμμή
.rest:  push bc
        push hl                 ; οθόνη
        push de                 ; buffer
        ld a,(fly_oh)
        or a
        jr z,.full
        ld a,(fly_ro0)          ; στην επικάλυψη: ro0 <= b < ro0 + h
        ld c,a
        ld a,b
        sub c
        jr c,.full
        ld c,a
        ld a,(fly_oh)
        dec a
        cp c
        jr c,.full
        ld a,(fly_ddx)
        call abs_a
        or a
        jr z,.next
        ld c,a
        ld a,(fly_ps)
        jr .copy
.full:  ld c,BOTTLE_W
        xor a
.copy:  pop de
        pop hl
        push hl
        push de
        ld b,0
        push bc                 ; πλήθος
        ld c,a                  ; στήλη
        add hl,bc
        ex de,hl
        add hl,bc               ; HL = buffer + στήλη, DE = οθόνη + στήλη
        pop bc
        ldir
.next:  pop de
        ld hl,BOTTLE_W
        add hl,de
        ex de,hl
        pop hl
        NEXT_LINE
        pop bc
        inc b
        ld a,b
        cp BOTTLE_H
        jr nz,.rest
        ld hl,(fly_old)         ; εναλλαγή των buffers
        ld de,(fly_new)
        ld (fly_old),de
        ld (fly_new),hl
        ld bc,(fly_nx)
        ld (fly_x),bc           ; fly_x = C, fly_y = B
        ret

; Γερμένο (pour_aim): ό,τι άφησε ξεσκέπαστο η διάτμηση μέσα στο όρθιο
; ορθογώνιο, από το fly_old. Γραμμή r με μετατόπιση p pixels, s = p sra 1:
; σκεπάζονται οι στήλες s .. s+7 (ως s+8 με μονό p).
unshear:
        ld a,(ix+B_X)
        ld c,a
        ld a,(ix+B_Y)
        call scr_addr
        ld de,(fly_old)
        xor a
        ld (tilt_row),a
.row:   push hl
        push de
        ld a,(tilt_row)
        call tilt_px
        ld b,a
        sra a
        jr z,.next              ; s = 0: τίποτα
        jp m,.left
        ld c,a                  ; s > 0: στήλες 0 .. s-1
        xor a
        jr .copy
.left:  bit 0,b                 ; s < 0: στήλες s+8+μονό .. 7
        jr z,.even
        inc a
.even:  add a,BOTTLE_W
        cp BOTTLE_W
        jr nc,.next
        ld c,a
        neg
        add a,BOTTLE_W
        ld b,c
        ld c,a                  ; πλήθος
        ld a,b                  ; στήλη
.copy:  ex de,hl                ; HL = buffer, DE = οθόνη
        ld b,0
        push bc
        ld c,a
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        ldir
.next:  pop de
        ld hl,BOTTLE_W
        add hl,de
        ex de,hl
        pop hl
        NEXT_LINE
        ld a,(tilt_row)
        inc a
        ld (tilt_row),a
        cp BOTTLE_H
        jr nz,.row
        ret

; A = |A|.
abs_a:
        or a
        ret p
        neg
        ret

; A με πρόσημο -> A = max(0, A), C = max(0, -A).
split:
        ld c,0
        or a
        ret p
        neg
        ld c,a
        xor a
        ret

; HL = A * BOTTLE_W (8). Κρατάει το BC.
times_w:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ret

;------------------------------------------------------------------
; A = A * E (8 bit, χωρίς υπερχείλιση). Αλλάζει B.
mul8:
        ld b,a
        xor a
        inc b
        dec b
        ret z
.add:   add a,e
        djnz .add
        ret

; C:HL = A * DE (24 bit). Αλλάζει B.
mul8x16:
        ld hl,0
        ld c,l
        ld b,8
.bit:   add hl,hl
        rl c
        rla
        jr nc,.next
        add hl,de
        jr nc,.next
        inc c
.next:  djnz .bit
        ret
