; options.asm — επιλογές (μουσική, εφέ, ταχύτητα, θέμα, πλήκτρα), που
; αποθηκεύονται στο LIQUID.SAV, και κοινά για τις οθόνες κειμένου.

; Πλήκτρα του matrix (γραμμή, bit) για τις οθόνες.
KR_D            equ 7
KB_D            equ %00100000
KR_O            equ 4
KB_O            equ %00000100
KR_H            equ 5
KB_H            equ %00010000
KR_S            equ 7
KB_S            equ %00010000
KR_DEL          equ 9
KB_DEL          equ %10000000
KR_RET          equ 2
KB_RET          equ %00000100
KR_ENTER        equ 0
KB_ENTER        equ %01000000
KR_ESC          equ 8
KB_ESC          equ %00000100

OPT_ITEMS       equ 6           ; μουσική, εφέ, ταχύτητα, θέμα, πλήκτρα, πίσω
OPT_Y           equ 40
OPT_DY          equ 18
OPT_VX          equ 46          ; x της τιμής

;------------------------------------------------------------------
; Στην εκκίνηση (μετά το load_progress): έλεγχος των τιμών του LIQUID.SAV,
; τα πλήκτρα στο key_bindings, το θέμα στην παλέτα.
apply_settings:
        ld hl,opt_music         ; 0/1
        ld b,4
.flag:  ld a,(hl)
        cp 2
        jr c,.ok
        ld (hl),0
.ok:    inc hl
        djnz .flag
        ld a,(theme_open)       ; το θέμα μόνο αν έχει ξεκλειδώσει
        or a
        jr nz,.keys
        ld (opt_theme),a
.keys:  ld hl,opt_keys          ; γραμμή < 10 και ακριβώς ένα bit
        ld b,5
.key:   ld a,(hl)
        cp 10
        jr nc,.bad
        inc hl
        ld a,(hl)
        or a
        jr z,.bad
        ld c,a
        dec a
        and c
        jr nz,.bad
        inc hl
        djnz .key
        jr .apply
.bad:   ld hl,default_keys
        ld de,opt_keys
        ld bc,10
        ldir
.apply: call apply_keys
        jp apply_theme

default_keys:   db 1,%00000001, 0,%00000010, 0,%00000001, 0,%00000100, 5,%10000000

; opt_keys (αριστερά, δεξιά, πάνω, κάτω, fire) -> key_bindings (πάνω, κάτω,
; αριστερά, δεξιά, fire: 3 bytes η καθεμία).
apply_keys:
        ld hl,opt_keys
        ld ix,key_order
        ld b,5
.k:     push bc
        ld e,(ix+0)
        inc ix
        ld d,0
        push hl
        ld hl,key_bindings
        add hl,de
        ex de,hl
        pop hl
        ldi
        ldi
        pop bc
        djnz .k
        ret

key_order:      db 6,9,0,3,12

; Το θέμα: CLASSIC (φόντο μαύρο-μπλε-ματζέντα, γκρι γυαλί) ή NEON (μαύρο
; φόντο, ροζ γυαλί). Κανένα χρώμα φόντου δεν είναι χρώμα υγρού.
apply_theme:
        ld a,(opt_theme)
        or a
        ld hl,theme_classic
        jr z,.set
        ld hl,theme_neon
.set:   ld de,bg_bands
        ld bc,6
        ldir
        ld a,(hl)
        ld (palette_hw+PEN_GLASS),a
        jp set_palette

theme_classic:  db #54,#54,#54,#44,#58,#58, #40
theme_neon:     db #54,#54,#54,#54,#54,#54, #4F

;------------------------------------------------------------------
; Κείμενο: σελίδες από εγγραφές «db y, x, pen, "ΚΕΙΜΕΝΟ",0», με #FF στο
; τέλος (x = #FF: στο κέντρο).
CENTER          equ #FF

print_page:
.line:  ld a,(hl)
        cp #FF
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call print_at
        pop hl
.skip:  ld a,(hl)               ; στο επόμενο
        inc hl
        or a
        jr nz,.skip
        jr .line

; Κείμενο HL στο y = B, x = C (CENTER: στο κέντρο), pen A.
print_at:
        push af
        ld a,c
        cp CENTER
        jr nz,.go
        call str_len
        ld a,40
        sub c
        ld c,a
.go:    pop af
        jp print_str

; C = μήκος του κειμένου HL.
str_len:
        push hl
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc c
        jr .l
.e:     pop hl
        ret

; Ολόκληρη οθόνη κειμένου: σβήσιμο, mode A, σελίδα HL.
text_screen:
        ld (mode),a
        push hl
        call cls
        pop hl
        jp print_page

; num5_buf = HL σε δεκαδικά, χωρίς μηδενικά μπροστά. out: HL = το κείμενο.
num5_str:
        ld de,num5_buf
        ld bc,-10000
        call .digit
        ld bc,-1000
        call .digit
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
        ld hl,num5_buf          ; χωρίς τα μηδενικά μπροστά (ένα μένει)
        ld b,4
.lead:  ld a,(hl)
        cp "0"
        ret nz
        inc hl
        djnz .lead
        ret
.digit: ld a,"0"-1
.sub:   inc a
        add hl,bc
        jr c,.sub
        sbc hl,bc
        ld (de),a
        inc de
        ret

num5_buf:       ds 6

;------------------------------------------------------------------
; Οθόνη επιλογών: πάνω/κάτω διαλέγει, SPACE/αριστερά/δεξιά αλλάζει, ESC πίσω.
options_start:
        ld hl,sfx_select
        call play_sfx
        xor a
        ld (opt_sel),a
        ld a,#FF
        ld (opt_redef),a
        ld hl,page_options
        ld a,MODE_OPTIONS
        call text_screen
        ld a,0
.it:    push af
        call opt_draw
        pop af
        inc a
        cp OPT_ITEMS
        jr nz,.it
        jp opt_keys_draw

options_frame:
        ld a,(opt_redef)        ; ορισμός πλήκτρων σε εξέλιξη
        cp #FF
        jp nz,redef_frame
        ld a,(input_new)
        and IN_ESC
        jp nz,opt_back
        ld a,(input_new)
        and IN_UP|IN_DOWN
        jr z,.chg
        ld b,a
        ld a,(opt_sel)
        ld c,a
        bit 0,b                 ; IN_UP
        jr z,.dn
        sub 1
        jr nc,.set
        ld a,OPT_ITEMS-1
        jr .set
.dn:    inc a
        cp OPT_ITEMS
        jr c,.set
        xor a
.set:   ld (opt_sel),a
        ld hl,sfx_tick
        call play_sfx
        ld a,c                  ; το παλιό χωρίς επισήμανση, το νέο με
        call opt_draw
        ld a,(opt_sel)
        jp opt_draw
.chg:   ld a,(input_new)
        and IN_FIRE|IN_LEFT|IN_RIGHT
        ret z
        ld a,(opt_sel)
        or a
        jr z,.music
        dec a
        jr z,.sfx
        dec a
        jr z,.speed
        dec a
        jr z,.theme
        dec a
        jr z,.keys
        jp opt_back
.music: ld hl,opt_music
        call .flip
        ld a,(opt_music)
        or a
        call z,music_stop
        call nz,music_start
        jr .redraw
.sfx:   ld hl,opt_sfx
        call .flip
        jr .redraw
.speed: ld hl,opt_speed
        call .flip
        jr .redraw
.theme: ld a,(theme_open)
        or a
        ld hl,sfx_error
        jp z,play_sfx
        ld hl,opt_theme
        call .flip
        call apply_theme
        jr .redraw
.keys:  xor a                   ; ορισμός: 5 πλήκτρα με τη σειρά
        ld (opt_redef),a
        ld hl,sfx_select
        call play_sfx
        jp redef_prompt
.flip:  ld a,(hl)
        xor 1
        ld (hl),a
        ld a,1
        ld (save_dirty),a
        ret
.redraw:
        ld hl,sfx_select
        call play_sfx
        ld a,(opt_sel)
        jp opt_draw

; Πίσω στον τίτλο, με αποθήκευση αν άλλαξε κάτι.
opt_back:
        call save_if_dirty
        jp title_start

; Η γραμμή A: όνομα (κίτρινο αν είναι η επιλεγμένη) και τιμή.
opt_draw:
        ld e,a
        add a,a                 ; y = OPT_Y + A * 18
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,OPT_Y
        ld b,a
        push bc
        push de
        ld c,4                  ; σβήσιμο όλης της γραμμής
        ld a,36
        call clear_text
        pop de
        pop bc
        push bc
        push de
        ld a,(opt_sel)
        cp e
        ld a,PEN_WHITE
        jr nz,.pen
        ld a,PEN_LIQUID+2
.pen:   ld d,0
        ld hl,opt_names
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld c,8
        call print_str
        pop de
        pop bc
        ld c,OPT_VX
        ld a,e
        ld hl,str_on            ; τιμή
        ld d,PEN_LIQUID+5
        or a
        jr nz,.n1
        ld a,(opt_music)
        jr .onoff
.n1:    dec a
        jr nz,.n2
        ld a,(opt_sfx)
.onoff: or a
        jr nz,.val
        ld hl,str_off
        ld d,PEN_GLASS
        jr .val
.n2:    dec a
        jr nz,.n3
        ld hl,str_normal
        ld a,(opt_speed)
        or a
        jr z,.val
        ld hl,str_fast
        jr .val
.n3:    dec a
        jr nz,.n4
        ld hl,str_locked
        ld d,PEN_GLASS
        ld a,(theme_open)
        or a
        jr z,.val
        ld d,PEN_LIQUID+5
        ld hl,str_classic
        ld a,(opt_theme)
        or a
        jr z,.val
        ld hl,str_neon
        jr .val
.n4:    dec a
        ret nz                  ; (πίσω: χωρίς τιμή)
        ld hl,str_redefine
.val:   ld a,d
        jp print_str

opt_names:      dw str_o_music,str_o_sfx,str_o_speed,str_o_theme,str_o_keys,str_o_back

; Τα 5 πλήκτρα κάτω από τις επιλογές: «L:LEFT R:RGHT ...».
KEYS_Y          equ OPT_Y+OPT_ITEMS*OPT_DY+4
opt_keys_draw:
        ld bc,KEYS_Y*256+0
        ld a,40
        call clear_text
        xor a
        ld (kidx),a
.k:     ld a,(kidx)
        ld e,a
        ld d,0
        ld hl,str_klet
        add hl,de
        ld a,(hl)
        ld (kbuf),a
        ld a,e                  ; x = 4 + 15k
        add a,a
        add a,a
        add a,a
        add a,a
        sub e
        add a,4
        ld c,a
        ld b,KEYS_Y
        ld hl,kbuf
        ld a,PEN_GLASS
        call print_str          ; «L:» (C += 4)
        push bc
        ld a,(kidx)
        add a,a
        ld e,a
        ld d,0
        ld hl,opt_keys
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        call key_name
        pop bc
        ld a,PEN_WHITE
        call print_str
        ld hl,kidx
        inc (hl)
        ld a,(hl)
        cp 5
        jr nz,.k
        ret

str_klet:       db "LRUDF"
kbuf:           db 0,":",0
kidx:           db 0

; HL = όνομα του πλήκτρου (A = γραμμή, E = bit).
key_name:
        ld b,-1                 ; αριθμός του bit
.bit:   inc b
        srl e
        jr nz,.bit
        add a,a                 ; (γραμμή * 8 + bit) * 5
        add a,a
        add a,a
        add a,b
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,key_names
        add hl,de
        ret

; Ορισμός πλήκτρων: opt_redef = ποιο από τα 5 περιμένει.
redef_prompt:
        ld bc,(KEYS_Y+14)*256+0
        ld a,40
        call clear_text
        ld hl,str_press_key
        ld bc,(KEYS_Y+14)*256+8
        ld a,PEN_LIQUID+2
        call print_str
        ld a,(opt_redef)
        add a,a
        ld e,a
        ld d,0
        ld hl,redef_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,PEN_WHITE
        ld b,KEYS_Y+14
        jp print_str            ; (συνεχίζει από το C του προηγούμενου)

redef_names:    dw str_k_left,str_k_right,str_k_up,str_k_down,str_k_fire

redef_frame:
        ld hl,keymap            ; πρώτο πλήκτρο που πατήθηκε τώρα (όχι ESC)
        ld de,keyprev
        ld c,0                  ; γραμμή
.row:   ld a,(hl)
        cpl
        ex de,hl
        and (hl)
        ex de,hl
        jr nz,.got
        inc hl
        inc de
        inc c
        ld a,c
        cp 10
        jr nz,.row
        ret
.got:   ld b,a                  ; το χαμηλότερο bit
        neg
        and b
        ld b,a
        ld a,c
        cp KR_ESC
        jr nz,.store
        ld a,b
        cp KB_ESC
        ret z
.store: ld a,(opt_redef)
        add a,a
        ld e,a
        ld d,0
        ld hl,opt_keys
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),b
        ld hl,sfx_tick
        call play_sfx
        ld a,1
        ld (save_dirty),a
        call opt_keys_draw
        ld hl,opt_redef
        inc (hl)
        ld a,(hl)
        cp 5
        jp c,redef_prompt
        ld (hl),#FF             ; τέλος
        call apply_keys
        ld bc,(KEYS_Y+14)*256+0
        ld a,40
        jp clear_text

opt_sel:        db 0
opt_redef:      db #FF

page_options:
        db 14,CENTER,PEN_LIQUID+2,"OPTIONS",0
        db 186,CENTER,PEN_GLASS,"UP/DOWN CHOOSE  SPACE CHANGE  ESC BACK",0
        db #FF

str_o_music:    db "MUSIC",0
str_o_sfx:      db "SOUND FX",0
str_o_speed:    db "SPEED",0
str_o_theme:    db "THEME",0
str_o_keys:     db "KEYS",0
str_o_back:     db "BACK",0
str_on:         db "ON",0
str_off:        db "OFF",0
str_normal:     db "NORMAL",0
str_fast:       db "FAST",0
str_locked:     db "LOCKED",0
str_classic:    db "CLASSIC",0
str_neon:       db "NEON",0
str_redefine:   db "REDEFINE",0
str_press_key:  db "PRESS A KEY FOR ",0
str_k_left:     db "LEFT",0
str_k_right:    db "RIGHT",0
str_k_up:       db "UP",0
str_k_down:     db "DOWN",0
str_k_fire:     db "FIRE",0

; Ονόματα των 80 πλήκτρων (γραμμή * 8 + bit), 5 bytes το καθένα.
key_names:
        db "UP",0,0,0,  "RGHT",0, "DOWN",0, "F9",0,0,0,  "F6",0,0,0,  "F3",0,0,0,  "ENT",0,0, "F.",0,0,0
        db "LEFT",0, "COPY",0, "F7",0,0,0,  "F8",0,0,0,  "F5",0,0,0,  "F1",0,0,0,  "F2",0,0,0,  "F0",0,0,0
        db "CLR",0,0, "LBR",0,0, "RET",0,0, "RBR",0,0, "F4",0,0,0,  "SHFT",0, "BSL",0,0, "CTRL",0
        db "HAT",0,0, "-",0,0,0,0,   "AT",0,0,0,  "P",0,0,0,0,   "SEMI",0, ":",0,0,0,0,   "/",0,0,0,0,   ".",0,0,0,0
        db "0",0,0,0,0,   "9",0,0,0,0,   "O",0,0,0,0,   "I",0,0,0,0,   "L",0,0,0,0,   "K",0,0,0,0,   "M",0,0,0,0,   "COMA",0
        db "8",0,0,0,0,   "7",0,0,0,0,   "U",0,0,0,0,   "Y",0,0,0,0,   "H",0,0,0,0,   "J",0,0,0,0,   "N",0,0,0,0,   "SPC",0,0
        db "6",0,0,0,0,   "5",0,0,0,0,   "R",0,0,0,0,   "T",0,0,0,0,   "G",0,0,0,0,   "F",0,0,0,0,   "B",0,0,0,0,   "V",0,0,0,0
        db "4",0,0,0,0,   "3",0,0,0,0,   "E",0,0,0,0,   "W",0,0,0,0,   "S",0,0,0,0,   "D",0,0,0,0,   "C",0,0,0,0,   "X",0,0,0,0
        db "1",0,0,0,0,   "2",0,0,0,0,   "ESC",0,0, "Q",0,0,0,0,   "TAB",0,0, "A",0,0,0,0,   "CAPS",0, "Z",0,0,0,0
        db "JUP",0,0, "JDN",0,0, "JLT",0,0, "JRT",0,0, "JF2",0,0, "JF1",0,0, "J7",0,0,  "DEL",0,0
