; sound.asm — ο AY-3-8912: εφέ (κανάλι B), γουργουρητό της μετάγγισης
; (κανάλι A, στο παιχνίδι) και η μουσική του τίτλου/μενού (A μελωδία, C μπάσο).
; Τα δεδομένα: assets/data/sound_data.asm (assets/src/make_sound.py).
;
; Το sound_frame τρέχει από το interrupt (int_handler), μία φορά ανά καρέ.
; Ο κύριος κώδικας μόνο αφήνει αιτήματα (play_sfx, pour_plip, music_start/
; stop) σε μεταβλητές· τα 16-bit γράφονται με μία εντολή, οπότε το interrupt
; δεν τα βλέπει ποτέ μισά. Ο mixer (reg 7) κρατάει το bit 6 στο 0: η θύρα I/O
; A του AY μένει είσοδος για το πληκτρολόγιο.

SOUND_INT       equ 3           ; στο 3ο interrupt μετά το VSYNC: στη μέση της
                                ; εικόνας, έξω από το παράθυρο των particles

; IM 1, 300 Hz: 6 interrupts ανά καρέ. Μόνο εκείνο που πέφτει 2 γραμμές μετά
; την αρχή του VSYNC βλέπει το bit του VSYNC στο PPI: από εκεί μετράμε.
int_handler:
        push af
        push bc
        ld b,PPI_B
        in a,(c)
        rra
        jr nc,.count
        xor a
        ld (int_idx),a
        jr .out
.count: ld a,(int_idx)
        inc a
        ld (int_idx),a
        cp SOUND_INT
        jr nz,.out
        push de
        push hl
        push ix
        call sound_frame
        pop ix
        pop hl
        pop de
.out:   pop bc
        pop af
        ei
        ret

MIX_TONES       equ %00111000   ; τόνοι A, B, C, χωρίς θόρυβο
MIX_NOISE_B     equ %00101010   ; τόνοι A, C· θόρυβος στο B
PLIP_LOUD       equ 12
PLIP_BASE       equ 320         ; περίοδος του γουργουρητού στον άδειο στόχο

; Register A του AY = E. Αλλάζει BC.
psg_write:
        ld b,#F4
        out (c),a
        ld bc,#F6C0             ; select register
        out (c),c
        ld bc,#F600
        out (c),c
        ld b,#F4
        out (c),e
        ld bc,#F680             ; write
        out (c),c
        ld bc,#F600
        out (c),c
        ret

sound_init:
        xor a
.reg:   ld e,0
        push af
        call psg_write
        pop af
        inc a
        cp 14
        jr nz,.reg
        ld a,7
        ld e,MIX_TONES
        call psg_write
        ld hl,0
        ld (sfx_ptr),hl
        xor a
        ld (plip_vol),a
        ld (music_on),a
        ret

; Εφέ στο κανάλι B (κόβει ό,τι έπαιζε εκεί). HL = sfx_*.
play_sfx:
        ld (sfx_ptr),hl
        ret

; Γουργουρητό: κάθε 3 γραμμές υγρού στον στόχο ένα «πλιπ», που ψηλώνει όσο
; ανεβαίνει η στάθμη (όπως σε αληθινό μπουκάλι). A = γραμμές του στόχου.
pour_plip:
        ld b,a
        and 3
        ret nz
        ld a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,PLIP_BASE
        or a
        sbc hl,de
        ld (plip_per),hl
        ld a,PLIP_LOUD
        ld (plip_vol),a
        ret

sound_frame:
        ld hl,snd_frame
        inc (hl)
        ; κανάλι B: εφέ
        ld hl,(sfx_ptr)
        ld a,h
        or l
        jr z,.silent
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        cp #FF
        jr nz,.play
        ld hl,0
        ld (sfx_ptr),hl
.silent:
        xor a
        ld (sfx_vol),a
        ld e,MIX_TONES
        jr .mix
.play:  ld (sfx_ptr),hl
        ld (sfx_vol),a
        bit 7,d
        jr nz,.noise
        push de
        ld a,2
        call psg_write
        pop de
        ld e,d
        ld a,3
        call psg_write
        ld e,MIX_TONES
        jr .mix
.noise: ld a,e
        and 31
        ld e,a
        ld a,6
        call psg_write
        ld e,MIX_NOISE_B
.mix:   ld a,7
        call psg_write
        ld a,(sfx_vol)
        ld e,a
        ld a,9
        call psg_write
        ld a,(music_on)
        or a
        jr nz,music_frame
        ; κανάλι A: γουργουρητό· C σιωπηλό
        ld hl,(plip_per)
        push hl
        ld e,l
        xor a
        call psg_write
        pop hl
        ld e,h
        ld a,1
        call psg_write
        ld a,(plip_vol)
        ld e,a
        ld a,8
        call psg_write
        ld a,(plip_vol)
        sub 2
        jr nc,.decay
        xor a
.decay: ld (plip_vol),a
        ld e,0
        ld a,10
        jp psg_write

;------------------------------------------------------------------
; Μουσική: δύο κανάλια (A μελωδία, C μπάσο), νότες που σβήνουν σιγά.
MC_PTR          equ 0           ; κανάλι μουσικής (MC_SIZE bytes)
MC_CNT          equ 2
MC_VOL          equ 3
MC_START        equ 4
MC_PREG         equ 6           ; register περιόδου (0 / 4)
MC_VREG         equ 7           ; register έντασης (8 / 10)
MC_SIZE         equ 8

music_start:
        ld a,(music_on)
        or a
        ret nz
        ld hl,music_init        ; (με music_on = 0 το interrupt δεν τα διαβάζει)
        ld de,mus_a
        ld bc,2*MC_SIZE
        ldir
        ld a,1
        ld (music_on),a
        ret

music_init:
        dw music_a
        db 1,0
        dw music_a
        db 0,8
        dw music_c
        db 1,0
        dw music_c
        db 4,10

; Ο κύριος κώδικας δεν γράφει ποτέ στον AY (το κάνει μόνο το interrupt):
; με music_on = 0 το sound_frame βάζει το γουργουρητό στο A και σιγή στο C.
music_stop:
        xor a
        ld (music_on),a
        ret

music_frame:
        ld ix,mus_a
        call mus_channel
        ld ix,mus_c
mus_channel:
        dec (ix+MC_CNT)
        jr nz,.env
        ld l,(ix+MC_PTR)
        ld h,(ix+MC_PTR+1)
        ld a,(hl)
        cp #FF
        jr nz,.note
        ld l,(ix+MC_START)      ; από την αρχή
        ld h,(ix+MC_START+1)
        ld a,(hl)
.note:  inc hl
        ld c,(hl)               ; καρέ
        inc hl
        ld (ix+MC_PTR),l
        ld (ix+MC_PTR+1),h
        ld (ix+MC_CNT),c
        ld (ix+MC_VOL),0
        or a
        jr z,.vol               ; παύση
        add a,a
        ld e,a
        ld d,0
        ld hl,note_table
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld a,(ix+MC_PREG)
        call psg_write
        pop de
        ld e,d
        ld a,(ix+MC_PREG)
        inc a
        call psg_write
        ld (ix+MC_VOL),13
        jr .vol
.env:   ld a,(snd_frame)        ; σβήνει ως το 6, ένα βήμα ανά 4 καρέ
        and 3
        jr nz,.vol
        ld a,(ix+MC_VOL)
        cp 7
        jr c,.vol
        dec (ix+MC_VOL)
.vol:   ld e,(ix+MC_VOL)
        ld a,(ix+MC_VREG)
        jp psg_write
