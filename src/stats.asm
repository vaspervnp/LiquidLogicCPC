; stats.asm — στατιστικά και μετάλλια (S στον τίτλο), ό,τι γίνεται σε κάθε
; νίκη (win_stats, medal_toast), και η «Χαλάρωση» με seed (D στον τίτλο).

MEDAL_COUNT     equ 12
MD_NO_UNDO      equ 8           ; μετάλλια-γεγονότα (τα άλλα από την πρόοδο)
MD_CLOSE        equ 9
MD_SEED         equ 11
TOAST_FRAMES    equ 100         ; κάθε γραμμή στο HUD της νίκης

;------------------------------------------------------------------
; Σε κάθε νίκη, πριν από τη γραμμή της νίκης: αστέρια (win_stars), μετρητής
; της «Χαλάρωσης», μετάλλια-γεγονότα, θέμα μετά την πίστα 100, νέα μετάλλια
; (medal_new) για το medal_toast.
win_stats:
        ld hl,(medals)
        ld (medal_old),hl
        ld a,(relax)
        or a
        jr z,.lv
        ld hl,(stat_relax)      ; «Χαλάρωση»
        inc hl
        ld a,h
        or l
        jr z,.rsat
        ld (stat_relax),hl
.rsat:  ld a,1                  ; (αποθήκευση όταν φύγεις από τη «Χαλάρωση»)
        ld (relax_dirty),a
        ld a,(relax_seed)
        or a
        jr z,.medals
        ld hl,medals+1
        set MD_SEED-8,(hl)
        jr .medals
.lv:    call award_stars
        ld (win_stars),a
        ld a,(undo_used)        ; από την πίστα 30 χωρίς undo
        or a
        jr nz,.time
        ld a,(level)
        cp 29
        jr c,.time
        ld hl,medals+1
        set MD_NO_UNDO-8,(hl)
.time:  ld a,(level_timer)      ; με το πολύ 10 δευτερόλεπτα
        or a
        jr z,.last
        ld hl,(time_left)
        ld a,h
        or a
        jr nz,.last
        ld a,l
        cp 11
        jr nc,.last
        ld hl,medals+1
        set MD_CLOSE-8,(hl)
.last:  ld a,(level)            ; η πίστα 100: ξεκλειδώνει το θέμα NEON
        cp LEVEL_COUNT-1
        jr nz,.medals
        ld a,1
        ld (theme_open),a
        ld (save_dirty),a
.medals:
        call medals_update
        ld hl,(medal_old)       ; νέα = medals & ~παλιά
        ld de,(medals)
        ld a,l
        cpl
        and e
        ld l,a
        ld a,h
        cpl
        and d
        ld h,a
        ld (medal_new),hl
        ld a,h
        or l
        jr z,.t
        ld a,(relax)
        or a
        ld a,1
        jr z,.save
        ld (relax_dirty),a
        jr .t
.save:  ld (save_dirty),a
.t:     ld a,60
        ld (toast_t),a
        ld a,MEDAL_COUNT
        ld (toast_i),a
        ret

; Τα μετάλλια της προόδου (πίστες, αστέρια, «Χαλάρωση», μεταγγίσεις), στο
; medals. Τα άλλα (γεγονότα) μένουν όπως είναι.
medals_update:
        ld hl,stars             ; D = λυμένες, E = με 3 αστέρια
        ld b,MAX_LEVELS
        ld de,0
.cnt:   ld a,(hl)
        inc hl
        or a
        jr z,.n
        inc d
        cp 3
        jr nz,.n
        inc e
.n:     djnz .cnt
        ld hl,(medals)
        ld a,d
        cp 1
        jr c,.m
        set 0,l
        cp 10
        jr c,.m
        set 1,l
        cp 50
        jr c,.m
        set 2,l
        cp 100
        jr c,.m
        set 3,l
.m:     ld a,e
        cp 10
        jr c,.r
        set 4,l
        cp 100
        jr c,.r
        set 5,l
.r:     push hl
        ld hl,(stat_relax)
        ld de,10
        or a
        sbc hl,de
        pop hl
        jr c,.p
        set 6,l
        push hl
        ld hl,(stat_relax)
        ld de,100
        or a
        sbc hl,de
        pop hl
        jr c,.p
        set 7,l
.p:     push hl
        ld hl,(stat_pours)
        ld de,1000
        or a
        sbc hl,de
        pop hl
        jr c,.done
        set 10-8,h
.done:  ld (medals),hl
        ret

; Στο ST_WIN, ανά καρέ: η γραμμή της νίκης και τα νέα μετάλλια εναλλάξ
; (toast_i = MEDAL_COUNT: η γραμμή της νίκης).
medal_toast:
        ld hl,(medal_new)
        ld a,h
        or l
        ret z
        ld hl,toast_t
        dec (hl)
        ret nz
        ld (hl),TOAST_FRAMES
        ld a,(toast_i)
.next:  inc a
        cp MEDAL_COUNT+1
        jr c,.chk
        xor a
.chk:   cp MEDAL_COUNT
        jr z,.line
        call medal_bit          ; Z = όχι νέο
        jr z,.next
        ld (toast_i),a
        push af
        ld hl,str_medal         ; «MEDAL: ΟΝΟΜΑ»
        ld de,toast_buf
        ld bc,7
        ldir
        pop af
        call medal_name
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.cp
        ld hl,sfx_chime
        call play_sfx
        ld hl,toast_buf
        ld a,PEN_LIQUID+2
        jp hud_message
.line:  ld (toast_i),a
        jp win_line

; NZ = το bit A του medal_new. Κρατάει το A.
medal_bit:
        push af
        ld hl,(medal_new)
        or a
        jr z,.t
        ld b,a
.sh:    srl h
        rr l
        djnz .sh
.t:     pop af
        bit 0,l
        ret

; NZ = το μετάλλιο A έχει κερδηθεί. Κρατάει το A.
medal_has:
        push af
        ld hl,(medals)
        or a
        jr z,.t
        ld b,a
.sh:    srl h
        rr l
        djnz .sh
.t:     pop af
        bit 0,l
        ret

; HL = όνομα του μεταλλίου A. Κρατάει το DE.
medal_name:
        push de
        add a,a
        ld e,a
        ld d,0
        ld hl,medal_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ret

medal_old:      dw 0
medal_new:      dw 0
toast_t:        db 0
toast_i:        db 0
win_stars:      db 0
str_medal:      db "MEDAL: "
toast_buf:      ds 32

medal_names:
        dw md0,md1,md2,md3,md4,md5,md6,md7,md8,md9,md10,md11
medal_descs:
        dw mdd0,mdd1,mdd2,mdd3,mdd4,mdd5,mdd6,mdd7,mdd8,mdd9,mdd10,mdd11
md0:    db "FIRST DROP",0
md1:    db "TEN DOWN",0
md2:    db "HALFWAY",0
md3:    db "CENTURY",0
md4:    db "PERFECT TEN",0
md5:    db "PERFECTIONIST",0
md6:    db "UNWINDING",0
md7:    db "ZEN MASTER",0
md8:    db "NO REGRETS",0
md9:    db "CLOSE CALL",0
md10:   db "BUSY HANDS",0
md11:   db "GARDENER",0
mdd0:   db "SOLVE YOUR FIRST LEVEL",0
mdd1:   db "SOLVE 10 LEVELS",0
mdd2:   db "SOLVE 50 LEVELS",0
mdd3:   db "SOLVE ALL 100 LEVELS",0
mdd4:   db "3 STARS ON 10 LEVELS",0
mdd5:   db "3 STARS ON ALL 100 LEVELS",0
mdd6:   db "SOLVE 10 RELAX PUZZLES",0
mdd7:   db "SOLVE 100 RELAX PUZZLES",0
mdd8:   db "LEVEL 30+ WITHOUT ANY UNDO",0
mdd9:   db "BEAT THE CLOCK WITH 10 S LEFT",0
mdd10:  db "POUR 1000 TIMES",0
mdd11:  db "SOLVE A SEEDED PUZZLE",0

;------------------------------------------------------------------
; Στατιστικά: αριθμοί, και τα 12 μετάλλια σε δύο στήλες· με τα βελάκια
; διαλέγεις ένα και βλέπεις τι χρειάζεται.
ST_X            equ 58              ; x των αριθμών
MD_Y            equ 100
MD_DY           equ 12

stats_start:
        ld hl,sfx_select
        call play_sfx
        call medals_update          ; (π.χ. από παλιά πρόοδο)
        xor a
        ld (md_sel),a
        ld hl,page_stats
        ld a,MODE_STATS
        call text_screen
        ld hl,stars                 ; λυμένες, αστέρια, με 3
        ld b,MAX_LEVELS
        ld de,0
        ld c,0
.cnt:   ld a,(hl)
        inc hl
        or a
        jr z,.n
        inc d
        push af
        add a,e
        ld e,a
        jr nc,.nc
        inc c                       ; (αστέρια > 255: C:E)
.nc:    pop af
        cp 3
        jr nz,.n
        push hl
        ld hl,st_perfect
        inc (hl)
        pop hl
.n:     djnz .cnt
        push bc
        push de
        ld l,d                      ; λυμένες «N/100»
        ld h,0
        ld de,str_of100
        ld b,22
        call .num
        pop de
        pop bc
        ld l,e                      ; αστέρια «N/300»
        ld h,c
        ld de,str_of300
        ld b,34
        call .num
        ld a,(st_perfect)
        ld l,a
        ld h,0
        xor a
        ld (st_perfect),a
        ld de,0
        ld b,46
        call .num
        ld hl,(stat_pours)
        ld de,0
        ld b,58
        call .num
        ld hl,(stat_relax)
        ld de,0
        ld b,70
        call .num
        ld d,0                      ; μετάλλια «N/12»
        ld a,MEDAL_COUNT
.md:    dec a
        call medal_has
        jr z,.mn
        inc d
.mn:    or a
        jr nz,.md
        ld l,d
        ld h,0
        ld de,str_of12
        ld b,84
        call .num
        xor a
.list:  push af
        call md_draw
        pop af
        inc a
        cp MEDAL_COUNT
        jr nz,.list
        jp md_desc
; HL = αριθμός, DE = «/100» ή 0, B = y: στη θέση ST_X, κίτρινο.
.num:   push de
        push bc
        call num5_str
        pop bc
        ld c,ST_X
        ld a,PEN_LIQUID+2
        call print_str
        pop hl
        ld a,h
        or l
        ret z
        ld a,PEN_GLASS
        jp print_str

stats_frame:
        ld a,(input_new)
        and IN_ESC|IN_FIRE
        jp nz,title_start
        ld a,(input_new)
        and IN_UP|IN_DOWN|IN_LEFT|IN_RIGHT
        ret z
        ld b,a
        ld a,(md_sel)
        ld c,a
        bit 0,b                     ; πάνω/κάτω: ±1, αριστερά/δεξιά: ±6
        jr z,.d
        dec a
.d:     bit 1,b
        jr z,.l
        inc a
.l:     bit 2,b
        jr z,.r
        sub 6
.r:     bit 3,b
        jr z,.w
        add a,6
.w:     cp MEDAL_COUNT              ; κυκλικά (τα αρνητικά: > 127)
        jr c,.ok
        cp 128
        jr nc,.neg
        sub MEDAL_COUNT
        jr .ok
.neg:   add a,MEDAL_COUNT
.ok:    ld (md_sel),a
        ld hl,sfx_tick
        call play_sfx
        ld a,c
        call md_draw
        ld a,(md_sel)
        call md_draw
        jp md_desc

; Μετάλλιο A στη λίστα: κίτρινο αν κερδήθηκε, γκρι αλλιώς, με «*» αν είναι
; το επιλεγμένο.
md_draw:
        ld (md_i),a
        ld c,4                      ; στήλη: 0-5 αριστερά, 6-11 δεξιά
        cp 6
        jr c,.col
        sub 6
        ld c,44
.col:   ld e,a                      ; y = MD_Y + γραμμή * 12
        add a,a
        add a,e
        add a,a
        add a,a
        add a,MD_Y
        ld b,a
        ld (md_bc),bc
        ld a,18
        call clear_text
        ld a,(md_sel)
        ld hl,md_i
        cp (hl)
        jr nz,.pen
        ld bc,(md_bc)
        ld hl,str_star
        ld a,PEN_WHITE
        call print_str
.pen:   ld a,(md_i)
        call medal_has
        ld a,PEN_GLASS
        jr z,.p
        ld a,PEN_LIQUID+2
.p:     ld (md_pen),a
        ld a,(md_i)
        call medal_name
        ld bc,(md_bc)
        inc c
        inc c
        ld a,(md_pen)
        jp print_str

md_i:           db 0
md_pen:         db 0
md_bc:          dw 0

md_desc:
        ld bc,(MD_Y+6*MD_DY+4)*256+0
        ld a,40
        call clear_text
        ld a,(md_sel)
        add a,a
        ld e,a
        ld d,0
        ld hl,medal_descs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld bc,(MD_Y+6*MD_DY+4)*256+CENTER
        ld a,PEN_LIQUID+5
        jp print_at

md_sel:         db 0
st_perfect:     db 0
str_star:       db "*",0
str_of100:      db "/100",0
str_of300:      db "/300",0
str_of12:       db "/12",0

page_stats:
        db 8,CENTER,PEN_LIQUID+2,"STATISTICS",0
        db 22,4,PEN_WHITE,"LEVELS SOLVED",0
        db 34,4,PEN_WHITE,"STARS",0
        db 46,4,PEN_WHITE,"PERFECT LEVELS",0
        db 58,4,PEN_WHITE,"POURS",0
        db 70,4,PEN_WHITE,"RELAX PUZZLES",0
        db 84,4,PEN_WHITE,"MEDALS",0
        db 190,CENTER,PEN_GLASS,"ARROWS MEDALS   SPACE BACK",0
        db #FF

;------------------------------------------------------------------
; Από τη «Χαλάρωση» στον τίτλο: αποθήκευση των μετρητών, μία φορά (όχι σε
; κάθε νίκη, που θα σταματούσε το παιχνίδι για ~5 s).
relax_leave:
        ld a,(relax_dirty)
        or a
        jr z,.t
        xor a
        ld (relax_dirty),a
        inc a
        ld (save_dirty),a
        call save_if_dirty
.t:     jp title_start

relax_dirty:    db 0

; HUD της «Χαλάρωσης»: RELAX, ή το seed.
relax_label:
        ld a,(relax_seed)
        or a
        ld hl,str_relax
        jr z,.p
        ld hl,(last_seed)
        call seed_str
.p:     ld bc,HUD_Y*256+1
        ld a,PEN_LIQUID+2
        jp print_str

; Στο «SOLVED!» με seed: «SEED-N» (ποια πίστα του seed).
seed_tag:
        ld a,(relax_seed)
        or a
        ret z
        ld hl,(last_seed)
        call seed_str
        ld bc,HUD_Y*256+18
        ld a,PEN_LIQUID+5
        call print_str
        ld hl,str_dash
        ld a,PEN_LIQUID+5
        call print_str
        ld a,(relax_num)
        call num_str
        ld hl,num_buf               ; χωρίς μηδενικά μπροστά
.z:     ld a,(hl)
        cp "0"
        jr nz,.n
        inc hl
        jr .z
.n:     ld a,PEN_LIQUID+5
        jp print_str

; HL = το seed HL σε 4 ψηφία (με μηδενικά).
seed_str:
        call num5_str
        ld hl,num5_buf+1
        ret

str_dash:       db "-",0

;------------------------------------------------------------------
; Οθόνη seed: 4 ψηφία (last_seed), DEL σβήνει, SPACE/RETURN ξεκινάει.
SEED_Y          equ 84
SEED_X          equ 32

seed_start:
        ld hl,sfx_select
        call play_sfx
        ld hl,page_seed
        ld a,MODE_SEED
        call text_screen
seed_draw:
        ld c,SEED_X
        ld a,SEED_Y
        call scr_addr
        ld bc,20*256+16
        call clear_rect
        ld hl,(last_seed)
        call seed_str
        ld bc,SEED_Y*256+SEED_X
        jp print_big

seed_frame:
        ld a,(input_new)
        and IN_ESC
        jp nz,title_start
        ld a,(input_new)
        and IN_FIRE
        jr nz,.go
        ld a,KR_RET
        ld c,KB_RET
        call key_new
        jr nz,.go
        ld a,KR_ENTER
        ld c,KB_ENTER
        call key_new
        jr nz,.go
        ld a,KR_DEL
        ld c,KB_DEL
        call key_new
        jr nz,.del
        ld hl,digit_keys            ; ψηφία: γραμμή, bit
        ld b,0
.dig:   push hl
        push bc
        ld a,(hl)
        inc hl
        ld c,(hl)
        call key_new
        pop bc
        pop hl
        jr nz,.got
        inc hl
        inc hl
        inc b
        ld a,b
        cp 10
        jr nz,.dig
        ret
.got:   push bc                     ; seed = (seed mod 1000) * 10 + ψηφίο
        ld hl,(last_seed)
        ld de,1000
.mod:   or a
        sbc hl,de
        jr nc,.mod
        add hl,de
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        pop bc
        ld e,b
        ld d,0
        add hl,de
        jr .set
.del:   ld hl,(last_seed)           ; seed / 10
        ld de,10
        ld bc,-1
.div:   inc bc
        or a
        sbc hl,de
        jr nc,.div
        ld h,b
        ld l,c
.set:   ld (last_seed),hl
        ld hl,sfx_tick
        call play_sfx
        jp seed_draw
.go:    ld a,1
        ld (relax_seed),a
        ld (relax_dirty),a
        jp relax_go

digit_keys:
        db 4,%00000001, 8,%00000001, 8,%00000010, 7,%00000010, 7,%00000001
        db 6,%00000010, 6,%00000001, 5,%00000010, 5,%00000001, 4,%00000010

page_seed:
        db 14,CENTER,PEN_LIQUID+2,"RELAX WITH A SEED",0
        db 36,CENTER,PEN_WHITE,"THE SAME SEED GIVES THE SAME",0
        db 48,CENTER,PEN_WHITE,"PUZZLES ON EVERY CPC.",0
        db 60,CENTER,PEN_WHITE,"SHARE IT WITH YOUR FRIENDS!",0
        db 120,CENTER,PEN_LIQUID+5,"TYPE 4 DIGITS   DEL ERASES",0
        db 140,CENTER,PEN_WHITE,"SPACE OR RETURN: PLAY",0
        db 186,CENTER,PEN_GLASS,"ESC BACK",0
        db #FF
