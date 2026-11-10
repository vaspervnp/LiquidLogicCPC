; help.asm — οδηγίες (4 σελίδες, H στον τίτλο) και κάρτες: την πρώτη φορά
; που μια πίστα έχει έναν ειδικό τύπο, πριν από την πίστα, μια σελίδα που
; τον εξηγεί με ένα μπουκάλι-παράδειγμα (seen_cards στο LIQUID.SAV).

HELP_PAGES      equ 4

help_start:
        ld hl,sfx_select
        call play_sfx
        xor a
        ld (help_page),a
help_show:
        ld a,(help_page)
        add a,a
        ld e,a
        ld d,0
        ld hl,help_table
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,MODE_HELP
        call text_screen
        ld hl,page_help_foot
        call print_page
        ld a,(help_page)        ; «1/4»
        add a,"1"
        ld (str_pageno),a
        ld hl,str_pageno
        ld bc,186*256+72
        ld a,PEN_GLASS
        jp print_str

help_frame:
        ld a,(input_new)
        and IN_ESC
        jp nz,title_start
        ld a,(input_new)
        and IN_FIRE|IN_RIGHT|IN_DOWN
        jr z,.back
        ld a,(help_page)
        inc a
        cp HELP_PAGES
        jp nc,title_start
        jr .go
.back:  ld a,(input_new)
        and IN_LEFT|IN_UP
        ret z
        ld a,(help_page)
        or a
        ret z
        dec a
.go:    ld (help_page),a
        ld hl,sfx_tick
        call play_sfx
        jp help_show

help_page:      db 0
str_pageno:     db "1/4",0
help_table:     dw page_help1,page_help2,page_help3,page_help4

page_help_foot:
        db 186,4,PEN_GLASS,"SPACE NEXT   ESC BACK",0
        db #FF

page_help1:
        db 10,CENTER,PEN_LIQUID+2,"HOW TO PLAY",0
        db 30,4,PEN_WHITE,"SORT THE LIQUIDS SO THAT EVERY",0
        db 42,4,PEN_WHITE,"BOTTLE HOLDS A SINGLE COLOUR.",0
        db 64,4,PEN_LIQUID+5,"ARROWS / JOYSTICK",0
        db 76,8,PEN_WHITE,"MOVE BETWEEN THE BOTTLES",0
        db 92,4,PEN_LIQUID+5,"SPACE",0
        db 104,8,PEN_WHITE,"PICK THE BOTTLE TO POUR FROM",0
        db 120,4,PEN_LIQUID+5,"SPACE AGAIN",0
        db 132,8,PEN_WHITE,"PICK THE BOTTLE TO FILL",0
        db 150,4,PEN_WHITE,"POUR ONTO THE SAME COLOUR OR INTO",0
        db 162,4,PEN_WHITE,"AN EMPTY BOTTLE. THE MATCHING TOP",0
        db 174,4,PEN_WHITE,"LAYERS FLOW WHILE THERE IS ROOM.",0
        db #FF

page_help2:
        db 10,CENTER,PEN_LIQUID+2,"KEYS AND STARS",0
        db 32,4,PEN_LIQUID+5,"U",0
        db 32,16,PEN_WHITE,"UNDO - 5 PER LEVEL",0
        db 46,4,PEN_LIQUID+5,"R",0
        db 46,16,PEN_WHITE,"RESTART THE LEVEL",0
        db 60,4,PEN_LIQUID+5,"E",0
        db 60,16,PEN_WHITE,"EXTRA BOTTLE - WHEN E+",0
        db 74,4,PEN_LIQUID+5,"ESC",0
        db 74,16,PEN_WHITE,"CANCEL OR PAUSE",0
        db 88,4,PEN_LIQUID+5,"M",0
        db 88,16,PEN_WHITE,"MENU - PAUSED OR SOLVED",0
        db 112,4,PEN_WHITE,"SOLVE A LEVEL IN THE FEWEST MOVES",0
        db 124,4,PEN_WHITE,"- PAR - FOR 3 STARS. EACH SOLVED",0
        db 136,4,PEN_WHITE,"LEVEL UNLOCKS THE NEXT ONE.",0
        db 156,4,PEN_WHITE,"KEYS, MUSIC AND SPEED: O ON THE",0
        db 168,4,PEN_WHITE,"TITLE SCREEN.",0
        db #FF

page_help3:
        db 10,CENTER,PEN_LIQUID+2,"SPECIAL BOTTLES",0
        db 30,4,PEN_LIQUID+5,"?",0
        db 30,22,PEN_WHITE,"HIDDEN LAYER",0
        db 44,4,PEN_LIQUID+5,"ICE",0
        db 44,22,PEN_WHITE,"FROZEN FOR SOME MOVES",0
        db 58,4,PEN_LIQUID+5,"LOCK",0
        db 58,22,PEN_WHITE,"OPENS WITH ITS COLOUR",0
        db 72,4,PEN_LIQUID+5,"BULB",0
        db 72,22,PEN_WHITE,"DROPPER: ONE LAYER",0
        db 86,4,PEN_LIQUID+5,"STRIPES",0
        db 86,22,PEN_WHITE,"CURTAIN: HIDDEN BOTTLE",0
        db 100,4,PEN_LIQUID+5,"TICKS",0
        db 100,22,PEN_WHITE,"A BOTTLE OF ANOTHER SIZE",0
        db 114,4,PEN_LIQUID+5,"LEFT",0
        db 114,22,PEN_WHITE,"MOVE LIMIT",0
        db 128,4,PEN_LIQUID+5,"TIME",0
        db 128,22,PEN_WHITE,"AGAINST THE CLOCK",0
        db 142,4,PEN_LIQUID+5,"E+",0
        db 142,22,PEN_WHITE,"EXTRA BOTTLE WITH E",0
        db 160,4,PEN_WHITE,"EACH ONE IS EXPLAINED THE FIRST",0
        db 172,4,PEN_WHITE,"TIME YOU MEET IT.",0
        db #FF

page_help4:
        db 10,CENTER,PEN_LIQUID+2,"RELAX AND SEEDS",0
        db 30,4,PEN_LIQUID+5,"R ON THE TITLE",0
        db 42,4,PEN_WHITE,"ENDLESS RANDOM PUZZLES WITHOUT",0
        db 54,4,PEN_WHITE,"STARS OR LIMITS. SPACE GIVES A",0
        db 66,4,PEN_WHITE,"NEW ONE WHEN SOLVED.",0
        db 86,4,PEN_LIQUID+5,"D ON THE TITLE",0
        db 98,4,PEN_WHITE,"TYPE A SEED OF 4 DIGITS. THE SAME",0
        db 110,4,PEN_WHITE,"SEED GIVES THE SAME PUZZLES ON",0
        db 122,4,PEN_WHITE,"EVERY CPC - PLAY THE SAME ONES",0
        db 134,4,PEN_WHITE,"AS YOUR FRIENDS!",0
        db 154,4,PEN_LIQUID+5,"S ON THE TITLE",0
        db 166,4,PEN_WHITE,"STATISTICS AND MEDALS",0
        db #FF

;------------------------------------------------------------------
; Κάρτες. Τα bits CD_* (seen_cards, 16 bits).
CD_HIDDEN       equ 0
CD_ICE          equ 1
CD_LOCK         equ 2
CD_MOVES        equ 3
CD_TALL         equ 4
CD_DROP         equ 5
CD_CURTAIN      equ 6
CD_TIMER        equ 7
CD_EXTRA        equ 8
CARD_BOT_X      equ 36
CARD_BOT_Y      equ 94

; Από το level_start, μετά το level_setup. out: Z = καμία κάρτα (η πίστα
; σχεδιάζεται), NZ = κάρτα στην οθόνη (MODE_CARD· μετά το level_show).
card_check:
        ld a,(relax)
        or a
        jr z,.lv
        xor a
        ret
.lv:    call level_types        ; HL = τύποι της πίστας
        ld de,(seen_cards)
        ld a,e                  ; νέοι = τύποι & ~seen
        cpl
        and l
        ld l,a
        ld a,d
        cpl
        and h
        ld h,a
        or l
        ret z
        ld (card_todo),hl
        ld a,(seen_cards)       ; seen |= νέοι
        or l
        ld (seen_cards),a
        ld a,(seen_cards+1)
        or h
        ld (seen_cards+1),a
        ld a,1
        ld (save_dirty),a
        ld a,(timer_on)         ; ο χρόνος σταματάει όσο φαίνεται η κάρτα
        ld (paused_timer),a
        xor a
        ld (timer_on),a
        call card_next
        or 1
        ret

; HL = CD_* της τρέχουσας πίστας (level_flags, μπουκάλια).
level_types:
        ld hl,0
        ld a,(level_flags)
        bit 0,a                 ; LF_HIDDEN
        jr z,.t1
        set CD_HIDDEN,l
.t1:    bit 1,a                 ; LF_MOVES
        jr z,.t2
        set CD_MOVES,l
.t2:    bit 2,a                 ; LF_TIMER
        jr z,.t3
        set CD_TIMER,l
.t3:    bit 3,a                 ; LF_EXTRA
        jr z,.t4
        set CD_EXTRA-8,h
.t4:    ld a,(level_cap)
        cp 4
        jr z,.bots
        set CD_TALL,l
.bots:  ld a,(nbottles)
        ld b,a
        ld ix,bottles
        ld de,BOT_SIZE
.bot:   ld a,(ix+B_FREEZE)
        or a
        jr z,.b1
        set CD_ICE,l
.b1:    ld a,(ix+B_LOCK)
        or a
        jr z,.b2
        set CD_LOCK,l
.b2:    bit BFB_DROPPER,(ix+B_FLAGS)
        jr z,.b3
        set CD_DROP,l
.b3:    bit BFB_CURTAIN,(ix+B_FLAGS)
        jr z,.b4
        set CD_CURTAIN,l
.b4:    ld a,(level_cap)
        cp (ix+B_CAP)
        jr z,.b5
        set CD_TALL,l
.b5:    add ix,de
        djnz .bot
        ret

; Η κάρτα του χαμηλότερου bit του card_todo (και το σβήνει από εκεί).
card_next:
        ld hl,(card_todo)
        ld c,0
.find:  srl h
        rr l
        jr c,.got
        inc c
        jr .find
.got:   ld a,c                  ; card_todo &= ~(1 << c)
        ld hl,1
        or a
        jr z,.mask
        ld b,a
.sh:    add hl,hl
        djnz .sh
.mask:  ld a,(card_todo)
        ld e,a
        ld a,l
        cpl
        and e
        ld (card_todo),a
        ld a,(card_todo+1)
        ld e,a
        ld a,h
        cpl
        and e
        ld (card_todo+1),a
        ld a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,card_table
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld b,0                  ; μπουκάλι-παράδειγμα
        ld hl,card_bots
        add hl,bc
        ld a,(hl)
        ld (card_bot_t),a
        pop hl
        ld a,MODE_CARD
        call text_screen
        ld hl,page_card_foot
        call print_page
        ld a,(card_bot_t)
        or a
        ret z
        ; το παράδειγμα: card_bot_t = δείκτης στο card_tpl (από 1)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,card_tpl
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = cap, flags, freeze, lock, πλήθος, στρώσεις
        ld ix,card_bot
        ld a,(hl)
        inc hl
        call bottle_init
        ld a,(hl)
        inc hl
        ld (ix+B_FLAGS),a
        ld a,(hl)
        inc hl
        ld (ix+B_FREEZE),a
        ld a,(hl)
        inc hl
        ld (ix+B_LOCK),a
        ld a,(hl)
        inc hl
        ld (ix+B_CNT),a
        ld b,a
        push ix
.lay:   ld a,(hl)
        inc hl
        ld (ix+B_LAY),a
        inc ix
        djnz .lay
        pop ix
        ld (ix+B_X),CARD_BOT_X
        ld (ix+B_Y),CARD_BOT_Y
        jp draw_bottle

card_frame:
        ld a,(input_new)
        and IN_FIRE|IN_ESC
        ret z
        ld hl,sfx_tick
        call play_sfx
        ld hl,(card_todo)
        ld a,h
        or l
        jp nz,card_next
        ld a,MODE_GAME          ; στην πίστα
        ld (mode),a
        ld a,(paused_timer)
        ld (timer_on),a
        call cls
        jp level_show

card_todo:      dw 0
card_bot_t:     db 0
card_bot:       ds BOT_SIZE

card_table:     dw card_hidden,card_ice,card_lock,card_moves,card_tall
                dw card_drop,card_curtain,card_timer,card_extra
card_bots:      db 1,2,3,0,4,5,6,0,0    ; card_tpl (από 1), 0 = χωρίς

; cap, bflags, πάγος, λουκέτο, πλήθος, στρώσεις
card_tpl:       dw tpl_hidden,tpl_ice,tpl_lock,tpl_tall,tpl_drop,tpl_curtain
tpl_hidden:     db 4,0,0,0,4, 6|#80,9|#80,4|#80,7
tpl_ice:        db 4,0,3,0,3, 5,8,5
tpl_lock:       db 4,0,0,9,2, 4,7
tpl_tall:       db 6,0,0,0,5, 10,10,6,13,4
tpl_drop:       db 4,BF_DROPPER,0,0,3, 12,7,7
tpl_curtain:    db 4,BF_CURTAIN,0,0,3, 6,9,4

page_card_foot:
        db 186,CENTER,PEN_GLASS,"SPACE CONTINUE",0
        db #FF

card_hidden:
        db 14,CENTER,PEN_LIQUID+2,"NEW: HIDDEN LAYERS",0
        db 36,4,PEN_WHITE,"SOME LAYERS ARE HIDDEN AND SHOW A",0
        db 48,4,PEN_WHITE,"? - A HIDDEN LAYER IS REVEALED",0
        db 60,4,PEN_WHITE,"WHEN IT REACHES THE TOP.",0
        db #FF
card_ice:
        db 14,CENTER,PEN_LIQUID+2,"NEW: FROZEN BOTTLE",0
        db 36,4,PEN_WHITE,"YOU CANNOT POUR FROM OR INTO IT.",0
        db 48,4,PEN_WHITE,"THE NUMBER SHOWS HOW MANY MOVES",0
        db 60,4,PEN_WHITE,"ARE LEFT UNTIL THE ICE MELTS.",0
        db #FF
card_lock:
        db 14,CENTER,PEN_LIQUID+2,"NEW: LOCKED BOTTLE",0
        db 36,4,PEN_WHITE,"IT OPENS WHEN ANOTHER BOTTLE IS",0
        db 48,4,PEN_WHITE,"COMPLETED IN THE COLOUR OF THE",0
        db 60,4,PEN_WHITE,"LOCK. UNTIL THEN IT STAYS SHUT.",0
        db #FF
card_moves:
        db 14,CENTER,PEN_LIQUID+2,"NEW: MOVE LIMIT",0
        db 36,4,PEN_WHITE,"SOLVE IT BEFORE YOU RUN OUT OF",0
        db 48,4,PEN_WHITE,"MOVES. LEFT AT THE TOP SHOWS HOW",0
        db 60,4,PEN_WHITE,"MANY YOU STILL HAVE.",0
        db 84,4,PEN_WHITE,"UNDO GIVES A MOVE BACK.",0
        db #FF
card_tall:
        db 14,CENTER,PEN_LIQUID+2,"NEW: TALL BOTTLES",0
        db 36,4,PEN_WHITE,"SOME BOTTLES HOLD MORE LAYERS.",0
        db 48,4,PEN_WHITE,"WHEN SIZES DIFFER WHITE TICKS ON",0
        db 60,4,PEN_WHITE,"THE GLASS MARK EACH LAYER.",0
        db #FF
card_drop:
        db 14,CENTER,PEN_LIQUID+2,"NEW: DROPPER",0
        db 36,4,PEN_WHITE,"A BOTTLE WITH A BULB POURS ONLY",0
        db 48,4,PEN_WHITE,"ONE LAYER AT A TIME.",0
        db #FF
card_curtain:
        db 14,CENTER,PEN_LIQUID+2,"NEW: CURTAIN",0
        db 36,4,PEN_WHITE,"THE BOTTLE HIDES BEHIND A CURTAIN",0
        db 48,4,PEN_WHITE,"UNTIL YOU POUR FROM OR INTO IT",0
        db 60,4,PEN_WHITE,"FOR THE FIRST TIME.",0
        db #FF
card_timer:
        db 14,CENTER,PEN_LIQUID+2,"NEW: AGAINST THE CLOCK",0
        db 36,4,PEN_WHITE,"SOLVE IT BEFORE THE TIME AT THE",0
        db 48,4,PEN_WHITE,"TOP RUNS OUT. ESC PAUSES THE",0
        db 60,4,PEN_WHITE,"CLOCK.",0
        db #FF
card_extra:
        db 14,CENTER,PEN_LIQUID+2,"NEW: EXTRA BOTTLE",0
        db 36,4,PEN_WHITE,"STUCK? PRESS E - ONCE PER LEVEL -",0
        db 48,4,PEN_WHITE,"FOR AN EXTRA EMPTY BOTTLE.",0
        db 60,4,PEN_WHITE,"E+ AT THE TOP SHOWS IT IS THERE.",0
        db #FF
