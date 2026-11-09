; pour.asm — μετάγγιση: κανόνες, ενημέρωση στρώσεων, τροχιά του πίδακα

APEX_H          equ 12          ; η κορυφή του τόξου, πάνω από το ψηλότερο στόμιο
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
        ; η πηγή γέρνει προς τον στόχο (όχι έξω από την οθόνη)
        ld a,(iy+B_X)
        cp (ix+B_X)
        ld b,0
        jr z,.tilt
        ld b,1
        jr nc,.right
        ld a,(ix+B_X)
        cp 2
        ld b,-1
        jr nc,.tilt
        ld b,0
        jr .tilt
.right: ld a,(ix+B_X)
        cp 80-BOTTLE_W-2+1
        jr c,.tilt
        ld b,0
.tilt:  ld (ix+B_TILT),b
        ld a,b
        or a
        call nz,redraw_bottle

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
        ; Από σειρά σε σειρά, οριζόντια κίνηση μόνο πάνω από την επάνω σειρά
        ; (y < clear_y): κάτω από εκεί ο πίδακας ανεβαίνει/πέφτει κατακόρυφα,
        ; στο κενό ανάμεσα στα μπουκάλια της άλλης σειράς.
        ld a,(ix+B_ROW)
        cp (iy+B_ROW)
        ld a,255
        jr z,.band
        ld a,ROW_Y1-2
.band:  ld (clear_y),a
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
        ld ix,(pour_src)
        ld (ix+B_RAISE),0
        ld (ix+B_TILT),0
        call redraw_bottle
        ld ix,(pour_dst)
        call check_done
        ld a,(ix+B_DONE)
        or a
        ret z
        ld hl,sfx_cork          ; φελλός
        call play_sfx
        jp draw_bottle

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
