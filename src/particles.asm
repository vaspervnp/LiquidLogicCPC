; particles.asm — η ροή του υγρού ως σωματίδια με βαρύτητα (plan.md §5)
;
; Αμέσως μετά το VSYNC, πριν φτάσει η δέσμη στην εικόνα (main.asm):
;   part_erase   σβήσιμο όσων σχεδιάστηκαν
;   liquid_sync  οι γραμμές υγρού του A/B φτάνουν τη λογική στάθμη
;   part_draw    σχεδίαση της λίστας που έχτισε η φυσική στο προηγούμενο καρέ
; Μετά, στο υπόλοιπο καρέ (particles_frame): εκπομπή από το στόμιο του A
; και φυσική, που γράφει τη νέα λίστα σχεδίασης.
;
; Σχεδίαση με XOR: το ίδιο XOR σχεδιάζει και σβήνει, με οποιαδήποτε σειρά,
; χωρίς save-under. Πάνω σε μαύρο (σχεδόν όλη η τροχιά) βγάζει ακριβώς το
; χρώμα· πάνω σε γυαλί/κείμενο, για ένα καρέ, άλλο χρώμα. Η λίστα (4 bytes ανά
; σωματίδιο: διεύθυνση, byte του XOR, κενό) διαβάζεται με POP από το stack,
; με DI (xor_list): ~29 NOPs ανά σωματίδιο, 64 σωματίδια < 2 ms.
; Οι γραμμές υγρού αλλάζουν μόνο ενώ τα σωματίδια είναι σβησμένα.
;
; Πτήση (ST 1): βαλλιστική τροχιά από το A στο λαιμό του B (pour.asm).
; Μέσα στο B (ST 2): τοίχοι, και στην επιφάνεια 1 στα 4 πιτσιλάει (ST 3)
; και τα υπόλοιπα απορροφώνται. Κάθε απορρόφηση προσθέτει dst_add στο
; dst_acc· ανά dst_thresh ανεβαίνει μια γραμμή του B.

; Εγγραφή σωματιδίου (P_SIZE bytes, στοιχισμένη στα 16: μέσα της αρκεί
; το inc l). Τα ζωντανά είναι πυκνά στην αρχή του particles (p_alive): νέο
; στο τέλος, και στη θέση ενός που σβήνει μπαίνει το τελευταίο.
P_ST            equ 0           ; 1 πτήση, 2 μέσα στο B, 3 πιτσίλισμα
P_VY            equ 1           ; 8.8 signed, γραμμές/καρέ
P_Y             equ 3           ; 8.8, γραμμές
P_VX            equ 5           ; 8.8 signed
P_X             equ 7           ; 8.8, pixels mode 0
P_SIZE          equ 16
L_SIZE          equ 4           ; λίστα σχεδίασης: διεύθυνση, XOR, κενό
MAX_PART        equ 64

PPL             equ 2           ; σωματίδια ανά γραμμή υγρού
EMIT_RATE       equ 2           ; εκπομπές ανά καρέ
SPLASH_MASK     equ 3           ; rnd & 3 = 0: πιτσίλισμα
VY_MAX          equ 4           ; γραμμές/καρέ, τελική ταχύτητα πτώσης

; HL στο πεδίο N της εγγραφής όπου δείχνει (αλλάζει το A).
        macro FIELD n
        ld a,l
        and #F0
        or {n}
        ld l,a
        mend

; Ανά καρέ της μετάγγισης, μετά το part_draw. out: Z = τελείωσε.
particles_frame:
        call part_emit
        call part_update
        ld hl,(emit_left)
        ld a,h
        or l
        ret nz
        ld a,(p_alive)
        or a
        ret

; HL = particles + A * P_SIZE. Αλλάζει DE.
part_ptr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,particles
        add hl,de
        ret

part_clear:
        xor a
        ld (p_alive),a
        ld (dlist_n),a          ; καμία λίστα
        ld (plist_n),a
        ld hl,dlist_a
        ld (dlist),hl
        ld hl,dlist_b
        ld (plist),hl
        ld (plist_end),hl
        ret

;------------------------------------------------------------------
; XOR της λίστας HL (A εγγραφές) στην οθόνη: με DI, το SP διαβάζει τη λίστα.
; Ο μετρητής στο B' (το BC' του firmware φυλάγεται: το χρειάζεται στο disc.asm).
xor_list:
        or a
        ret z
        di
        ld (sp_save),sp
        ld sp,hl
        exx
        ld (bc_save),bc
        ld b,a
        exx
.p:     pop de                  ; διεύθυνση (y ζυγό: η y+1 είναι +#800)
        pop bc                  ; C = XOR
        ld a,(de)
        xor c
        ld (de),a
        ld a,d
        add a,8
        ld d,a
        ld a,(de)
        xor c
        ld (de),a
        exx
        dec b
        exx
        jr nz,.p
        exx
        ld bc,(bc_save)
        exx
        ld sp,(sp_save)
        ei
        ret

part_erase:
        ld a,(dlist_n)
        ld hl,(dlist)
        call xor_list
        xor a
        ld (dlist_n),a
        ret

; Σχεδιάζει τη λίστα του plist, που γίνεται η dlist (για το επόμενο σβήσιμο).
part_draw:
        ld hl,(plist)
        ld (dlist),hl
        ld a,(plist_n)
        ld (dlist_n),a
        ld b,a
        xor a
        ld (plist_n),a          ; τίποτα εκκρεμές ως την επόμενη φυσική
        ld a,b
        jp xor_list

; Οι γραμμές υγρού στην οθόνη φτάνουν τις src_lines / dst_lines.
liquid_sync:
.src:   ld a,(src_lines)
        ld b,a
        ld a,(src_shown)
        cp b
        jr z,.dst
        jr c,.dst
        dec a
        ld (src_shown),a
        ld ix,(pour_src)
        ld c,0
        call liquid_row
        jr .src
.dst:   ld a,(dst_lines)
        ld b,a
        ld a,(dst_shown)
        cp b
        ret nc
        ld ix,(pour_dst)
        ld b,a
        ld a,(pour_pen)
        ld c,a
        ld a,b
        call liquid_row
        ld hl,dst_shown
        inc (hl)
        jr .dst

;------------------------------------------------------------------
part_emit:
        ld c,EMIT_RATE
.emit:  ld hl,(emit_left)
        ld a,h
        or l
        ret z
        ld a,(p_alive)          ; γεμάτο: περιμένει το επόμενο καρέ
        cp MAX_PART
        ret nc
        dec hl
        ld (emit_left),hl
        inc a
        ld (p_alive),a
        dec a
        call part_ptr
        push bc
        ld (hl),1               ; πτήση
        inc l
        ex de,hl                ; DE -> P_VY (το rnd αλλάζει HL)
        call rnd                ; vy = base_vy ± 16
        and 31
        sub 16
        ld c,a
        rla
        sbc a,a
        ld b,a
        ld hl,(base_vy)
        add hl,bc
        ex de,hl
        ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld de,(emit_y)
        ld (hl),e
        inc l
        ld (hl),d
        inc l
        ex de,hl                ; DE -> P_VX
        call rnd                ; vx = base_vx ± 32
        and 63
        sub 32
        ld c,a
        rla
        sbc a,a
        ld b,a
        ld hl,(base_vx)
        add hl,bc
        ex de,hl
        ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld de,(emit_x)
        ld (hl),e
        inc l
        ld (hl),d
        pop bc
.drain: ld hl,src_acc           ; ανά PPL εκπομπές, μια γραμμή λιγότερη στο A
        inc (hl)
        ld a,(hl)
        cp PPL
        jr c,.next
        ld (hl),0
        push bc
        call src_line_down
        pop bc
.next:  dec c
        jr nz,.emit
        ret

; Μια γραμμή λιγότερη στο A (αν δεν έφτασε στο src_final)· σχεδιάζεται στο
; liquid_sync.
src_line_down:
        ld a,(src_final)
        ld b,a
        ld a,(src_lines)
        cp b
        ret z
        ret c
        dec a
        ld (src_lines),a
        ret

; Μία γραμμή υγρού παραπάνω στο B (αν δεν έφτασε στο dst_target).
dst_line_up:
        ld a,(dst_target)
        ld b,a
        ld a,(dst_lines)
        cp b
        ret nc
        ld hl,dst_lines
        inc (hl)
        ld a,(hl)
        push bc
        call pour_plip          ; γουργουρητό
        pop bc
; dst_surf = η πρώτη άδεια γραμμή του B - 1: εκεί ακουμπάει το σωματίδιο
; (που πιάνει τις γραμμές y, y+1).
set_dst_surf:
        ld a,(dst_lines)
        ld b,a
        ld a,(dst_bottom)
        sub b
        dec a
        ld (dst_surf),a
        ret

;------------------------------------------------------------------
; Φυσική όλων των ζωντανών, και η νέα λίστα σχεδίασης. Χωρίς IX: HL δείχνει
; στην εγγραφή και προχωράει με inc l. Στο τέλος κάθε σωματιδίου B = x,
; C = y (ακέραια).
part_update:
        ld hl,(dlist)           ; η νέα λίστα στον άλλο buffer
        ld de,dlist_a
        or a
        sbc hl,de
        jr nz,.buf
        ld de,dlist_b
.buf:   ld (plist),de
        ld (plist_end),de
        xor a
        ld (plist_n),a
        ld a,(p_alive)
        or a
        ret z
        ld (upd_left),a
        ld hl,particles
.p:     ld a,(hl)               ; P_ST
        ld (cur_st),a
        inc l
        ld a,(hl)               ; vy += g, ως VY_MAX
        add a,GRAVITY
        ld e,a
        inc l
        ld a,(hl)
        adc a,0
        cp VY_MAX
        jr c,.vy
        cp #80
        jr nc,.vy               ; αρνητικό: ανεβαίνει
        ld a,VY_MAX
        ld e,0
.vy:    ld (hl),a
        ld d,a
        ld (cur_vyh),a
        dec l
        ld (hl),e
        inc l
        inc l                   ; P_Y
        ld a,(hl)               ; y += vy
        add a,e
        ld (hl),a
        inc l
        ld a,(hl)
        adc a,d
        ld (hl),a
        ld c,a                  ; C = y
        inc l                   ; P_VX
        ld e,(hl)
        inc l
        ld d,(hl)
        inc l                   ; P_X
        ld a,(cur_st)           ; σε πτήση, κάτω από τη ζώνη: κατακόρυφα
        dec a
        jr nz,.xmove
        ld a,c
        cp 240
        jr nc,.xmove            ; πάνω από την οθόνη
        ld a,(clear_y)
        ld b,a
        ld a,c
        cp b
        jr c,.xmove
        inc l
        ld b,(hl)
        jr .xdone
.xmove: ld a,(hl)               ; x += vx
        add a,e
        ld (hl),a
        inc l
        ld a,(hl)
        adc a,d
        ld (hl),a
        ld b,a                  ; B = x
.xdone: ld a,(cur_st)
        dec a
        jr nz,.inside

        ; πτήση
        ld a,b
        cp 160
        jp nc,.kill             ; έξω αριστερά/δεξιά
        ld a,c
        cp 240
        jp nc,.next             ; αρνητικό y: πάνω από την οθόνη
        cp 200
        jp nc,.kill
        ld a,(cur_vyh)
        rla
        jp c,.done              ; ανεβαίνει ακόμα
        ld a,(dst_entry)
        ld d,a
        ld a,c
        cp d
        jp c,.done
        FIELD P_ST              ; μπαίνει στο λαιμό του B
        ld (hl),2
        ld a,(dst_nl)
        cp b
        jr c,.nl
        ld b,a
.nl:    ld a,(dst_nr)
        cp b
        jr nc,.nr
        ld b,a
.nr:    FIELD P_X+1
        ld (hl),b
        push hl
        call rnd                ; πέφτει σχεδόν ίσια: vx = ±16
        pop hl
        and 31
        sub 16
        ld e,a
        FIELD P_VX
        ld (hl),e
        inc l
        ld a,e
        rla
        sbc a,a
        ld (hl),a
        jp .done

.inside:
        ld a,(dst_xl)           ; τοίχοι: vx = -vx/2
        ld d,a
        ld a,b
        cp d
        jr c,.wall
        ld a,(dst_xr)
        ld d,a
        ld a,b
        cp d
        jr z,.surf
        jr c,.surf
.wall:  ld b,d
        ld (hl),b               ; (HL -> P_X+1)
        FIELD P_VX
        ld e,(hl)
        inc l
        ld d,(hl)
        sra d
        rr e
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld (hl),a
        dec l
        ld (hl),e
.surf:  ld a,(dst_surf)
        ld d,a
        ld a,c
        and #FE
        cp d
        jr c,.done
        ld a,(cur_st)           ; στην επιφάνεια
        cp 2
        jr nz,.absorb
        push hl
        call rnd
        pop hl
        and SPLASH_MASK
        jr nz,.absorb
        FIELD P_ST              ; πιτσίλισμα: vy = -vy/4, πλάγια ταχύτητα
        ld (hl),3
        inc l
        ld e,(hl)
        inc l
        ld d,(hl)
        sra d
        rr e
        sra d
        rr e
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld (hl),a
        dec l
        ld (hl),e
        inc l
        inc l
        inc l                   ; P_Y+1
        ld a,(dst_surf)
        sub 2
        ld (hl),a
        ld c,a
        push hl
        call rnd
        pop hl
        and 127
        sub 64
        inc l                   ; P_VX
        ld (hl),a
        inc l
        rla
        sbc a,a
        ld (hl),a
        jr .done
.absorb:
        push hl
        call absorb
        pop hl
.kill:  FIELD P_ST              ; το τελευταίο (ακόμα όχι ενημερωμένο) στη θέση του
        ld a,(p_alive)
        dec a
        ld (p_alive),a
        ld e,a
        ld a,(upd_left)
        dec a
        ld (upd_left),a
        ret z
        push hl
        ld a,e
        call part_ptr
        pop de
        push de
        ld bc,P_SIZE
        ldir
        pop hl
        jp .p
.done:  ld a,b                  ; στη λίστα σχεδίασης, αν είναι στην οθόνη
        cp 160
        jr nc,.next
        ld a,c
        cp 198
        jr nc,.next
        push hl
        and #FE                 ; ζυγό y: η y+1 είναι +#800
        ld l,a
        ld h,hi(line_lo)
        ld e,(hl)
        inc h
        ld d,(hl)
        ld a,b
        srl a
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        ld hl,(plist_end)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(pour_pl)          ; ζυγό x: αριστερό pixel
        bit 0,b
        jr z,.pen
        ld a,(pour_pr)
.pen:   ld (hl),a
        inc hl
        inc hl
        ld (plist_end),hl
        ld hl,plist_n
        inc (hl)
        pop hl
.next:  ld a,l                  ; επόμενη εγγραφή
        and #F0
        add a,P_SIZE
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,(upd_left)
        dec a
        ld (upd_left),a
        jp nz,.p
        ret

absorb:
        ld a,(dst_add)
        ld hl,dst_acc
        add a,(hl)
        ld (hl),a
.line:  ld a,(dst_thresh)
        ld c,a
        ld a,(dst_acc)
        cp c
        ret c
        sub c
        ld (dst_acc),a
        call dst_line_up
        jr .line
