; particles.asm — η ροή του υγρού ως σωματίδια με βαρύτητα (plan.md §5)
;
; Αμέσως μετά το VSYNC, πριν φτάσει η δέσμη στην εικόνα (main.asm):
;   part_erase   σβήσιμο όσων σχεδιάστηκαν (save-under, αντίστροφη σειρά)
;   liquid_sync  οι γραμμές υγρού του A/B φτάνουν τη λογική στάθμη
;   part_draw    σχεδίαση της λίστας που έχτισε η φυσική στο προηγούμενο καρέ
; Μετά, στο υπόλοιπο καρέ (particles_frame): εκπομπή από το στόμιο του A
; και φυσική, που γράφει τη νέα λίστα σχεδίασης (διεύθυνση, μάσκα, pen).
; Οι γραμμές υγρού αλλάζουν μόνο ενώ τα σωματίδια είναι σβησμένα, οπότε το
; save-under δεν ξαναγράφει ποτέ παλιό περιεχόμενο πάνω τους.
;
; Πτήση (P_ST 1): βαλλιστική τροχιά από το A στο λαιμό του B (pour.asm).
; Μέσα στο B (P_ST 2): τοίχοι, και στην επιφάνεια 1 στα 4 πιτσιλάει (P_ST 3)
; και τα υπόλοιπα απορροφώνται. Κάθε απορρόφηση προσθέτει dst_add στο
; dst_acc· ανά dst_thresh ανεβαίνει μια γραμμή του B.

; Τα ζωντανά σωματίδια είναι πυκνά στην αρχή του particles (p_alive): νέο
; στο τέλος, και στη θέση ενός που σβήνει μπαίνει το τελευταίο.
P_ST            equ 0           ; 1 πτήση, 2 μέσα στο B, 3 πιτσίλισμα
P_X             equ 1           ; 8.8, pixels mode 0
P_Y             equ 3           ; 8.8, γραμμές
P_VX            equ 5           ; 8.8 signed
P_VY            equ 7           ; 8.8 signed
P_SIZE          equ 16

; Λίστα σχεδίασης: ανά σωματίδιο διεύθυνση (y ζυγό: η y+1 είναι +#800),
; μάσκα του άλλου pixel, pen bits, και τα 2 bytes κάτω από αυτό.
L_SIZE          equ 6
MAX_PART        equ 40

PPL             equ 2           ; σωματίδια ανά γραμμή υγρού
EMIT_RATE       equ 2           ; εκπομπές ανά καρέ
SPLASH_MASK     equ 3           ; rnd & 3 = 0: πιτσίλισμα
VY_MAX          equ 4           ; γραμμές/καρέ, τελική ταχύτητα πτώσης

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

; HL = particles + A * P_SIZE
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
        ld hl,particles
        ld de,particles+1
        ld bc,MAX_PART*P_SIZE-1
        ld (hl),0
        ldir
        xor a
        ld (p_alive),a
        ld (dlist_n),a          ; καμία λίστα
        ld (plist_n),a
        ld hl,dlist_a
        ld (dlist),hl
        ld (dlist_end),hl
        ld hl,dlist_b
        ld (plist),hl
        ld (plist_end),hl
        ret

;------------------------------------------------------------------
part_erase:
        ld a,(dlist_n)
        or a
        ret z
        ld b,a
        xor a
        ld (dlist_n),a
        ld hl,(dlist_end)
.p:     dec hl
        ld c,(hl)               ; byte της γραμμής y+1
        dec hl
        ld a,(hl)               ; byte της γραμμής y
        dec hl
        dec hl
        dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)
        ld (de),a
        ld a,d
        add a,8
        ld d,a
        ld a,c
        ld (de),a
        djnz .p
        ret

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
        dec hl
        ld (emit_left),hl
        ld ix,particles
        ld b,MAX_PART
        ld de,P_SIZE
.find:  ld a,(ix+P_ST)
        or a
        jr z,.got
        add ix,de
        djnz .find
        jr .drain               ; όλα πιασμένα: χάνεται, το τέλος διορθώνει τη στάθμη
.got:   ld (ix+P_ST),1
        ld hl,p_alive
        inc (hl)
        ld hl,(emit_x)
        ld (ix+P_X),l
        ld (ix+P_X+1),h
        ld hl,(emit_y)
        ld (ix+P_Y),l
        ld (ix+P_Y+1),h
        call rnd                ; vx = base_vx ± 32
        and 63
        sub 32
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld hl,(base_vx)
        add hl,de
        ld (ix+P_VX),l
        ld (ix+P_VX+1),h
        call rnd                ; vy = base_vy ± 16
        and 31
        sub 16
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld hl,(base_vy)
        add hl,de
        ld (ix+P_VY),l
        ld (ix+P_VY+1),h
.drain: ld hl,src_acc           ; ανά PPL εκπομπές, μια γραμμή λιγότερη στο A
        inc (hl)
        ld a,(hl)
        cp PPL
        jr c,.next
        ld (hl),0
        call src_line_down
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
        ld ix,particles
        ld b,MAX_PART
        ld a,(p_alive)
        or a
        ret z
        ld b,a
.p:     push bc
        ld l,(ix+P_VY)          ; vy += g, y += vy
        ld h,(ix+P_VY+1)
        ld de,GRAVITY
        add hl,de
        ld a,h                  ; τελική ταχύτητα: vy <= VY_MAX
        cp VY_MAX
        jr c,.vy
        bit 7,h
        jr nz,.vy
        ld hl,VY_MAX*256
.vy:    ld (ix+P_VY),l
        ld (ix+P_VY+1),h
        ex de,hl
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        add hl,de
        ld (ix+P_Y),l
        ld (ix+P_Y+1),h
        ld a,(ix+P_ST)          ; σε πτήση, κάτω από τη ζώνη: κατακόρυφα
        dec a
        jr nz,.xmove
        ld a,h
        cp 240
        jr nc,.xmove            ; πάνω από την οθόνη
        ld hl,clear_y
        cp (hl)
        jr c,.xmove
        ld h,(ix+P_X+1)
        jr .xdone
.xmove: ld e,(ix+P_VX)          ; x += vx
        ld d,(ix+P_VX+1)
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        add hl,de
        ld (ix+P_X),l
        ld (ix+P_X+1),h
.xdone:
        ld a,(ix+P_ST)
        dec a
        jr nz,.inside

        ; πτήση
        ld a,h
        cp 160
        jp nc,.kill             ; έξω αριστερά/δεξιά
        ld a,(ix+P_Y+1)
        cp 240
        jp nc,.done             ; αρνητικό y: πάνω από την οθόνη
        cp 200
        jp nc,.kill
        bit 7,(ix+P_VY+1)
        jp nz,.done             ; ανεβαίνει ακόμα
        ld hl,dst_entry
        cp (hl)
        jp c,.done
        ld (ix+P_ST),2          ; μπαίνει στο λαιμό του B
        ld a,(ix+P_X+1)
        ld hl,dst_nl
        cp (hl)
        jr nc,.nl
        ld a,(hl)
.nl:    ld hl,dst_nr
        cp (hl)
        jr c,.nr
        ld a,(hl)
.nr:    ld (ix+P_X+1),a
        call rnd                ; πέφτει σχεδόν ίσια: vx = ±16
        and 31
        sub 16
        ld (ix+P_VX),a
        rla
        sbc a,a
        ld (ix+P_VX+1),a
        jp .done

.inside:
        ld a,(ix+P_X+1)         ; τοίχοι: vx = -vx/2
        ld hl,dst_xl
        cp (hl)
        jr c,.wall
        ld hl,dst_xr
        cp (hl)
        jr z,.surf
        jr c,.surf
.wall:  ld a,(hl)
        ld (ix+P_X+1),a
        ld l,(ix+P_VX)
        ld h,(ix+P_VX+1)
        sra h
        rr l
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld (ix+P_VX),l
        ld (ix+P_VX+1),a
.surf:  ld a,(ix+P_Y+1)
        and #FE
        ld hl,dst_surf
        cp (hl)
        jr c,.done
        ld a,(ix+P_ST)          ; στην επιφάνεια
        cp 2
        jr nz,.absorb
        call rnd
        and SPLASH_MASK
        jr nz,.absorb
        ld (ix+P_ST),3          ; πιτσίλισμα: vy = -vy/4, πλάγια ταχύτητα
        ld l,(ix+P_VY)
        ld h,(ix+P_VY+1)
        sra h
        rr l
        sra h
        rr l
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld (ix+P_VY),l
        ld (ix+P_VY+1),a
        ld a,(dst_surf)
        sub 2
        ld (ix+P_Y+1),a
        call rnd
        and 127
        sub 64
        ld (ix+P_VX),a
        rla
        sbc a,a
        ld (ix+P_VX+1),a
        jr .done
.absorb:
        call absorb
.kill:  ld hl,p_alive           ; το τελευταίο (ακόμα όχι ενημερωμένο) στη θέση του
        dec (hl)
        ld a,(hl)
        pop bc
        dec b
        ret z
        push bc
        call part_ptr
        push ix
        pop de
        ld bc,P_SIZE
        ldir
        pop bc
        jp .p
.done:  call plist_add
        pop bc
.next:  ld de,P_SIZE
        add ix,de
        dec b
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

;------------------------------------------------------------------
; Προσθέτει το σωματίδιο IX στη λίστα σχεδίασης (αν είναι στην οθόνη).
plist_add:
        ld a,(ix+P_X+1)
        cp 160
        ret nc
        ld c,a
        ld a,(ix+P_Y+1)
        cp 198
        ret nc
        and #FE                 ; ζυγό y: η y+1 είναι +#800
        ld l,a
        ld h,hi(line_lo)
        ld e,(hl)
        inc h
        ld d,(hl)
        ld a,c
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
        bit 0,c
        jr nz,.right
        ld (hl),#55             ; ζυγό x: αριστερό pixel
        inc hl
        ld a,(pour_pl)
        jr .pen
.right: ld (hl),#AA
        inc hl
        ld a,(pour_pr)
.pen:   ld (hl),a
        inc hl
        inc hl
        inc hl
        ld (plist_end),hl
        ld hl,plist_n
        inc (hl)
        ret

; Σχεδιάζει τη λίστα του plist, που γίνεται η dlist (για το επόμενο σβήσιμο).
part_draw:
        ld a,(plist_n)
        ld (dlist_n),a
        or a
        ret z
        ld b,a
        xor a
        ld (plist_n),a          ; τίποτα εκκρεμές ως την επόμενη φυσική
        ld hl,(plist_end)
        ld (dlist_end),hl
        ld hl,(plist)
        ld (dlist),hl
.p:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)               ; μάσκα
        inc hl
        ld a,(de)
        inc hl
        ld (hl),a               ; save y
        and c
        dec hl
        or (hl)                 ; pen
        ld (de),a
        ld a,d
        add a,8
        ld d,a
        ld a,(de)
        inc hl
        inc hl
        ld (hl),a               ; save y+1
        and c
        dec hl
        dec hl
        or (hl)
        ld (de),a
        inc hl
        inc hl
        inc hl
        djnz .p
        ret
