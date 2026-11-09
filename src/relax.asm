; relax.asm — «Χαλάρωση»: ατελείωτες τυχαίες πίστες, χωρίς αστέρια και
; αποθήκευση. 5-8 χρώματα (τυχαία από τα 12), 4 στρώσεις, δύο άδεια
; μπουκάλια και το έξτρα (E). Ανακατεύονται όλες οι στρώσεις μαζί· όσες
; ανακατωσιές αφήνουν μπουκάλι ήδη μονόχρωμο απορρίπτονται.

; Γράφει μια καινούργια πίστα στο level_buf (μορφή levels.asm).
relax_gen:
        ld hl,relax_cols        ; τα χρώματα: 12 pens, ανακατεμένα
        ld a,PEN_LIQUID
        ld b,12
.col:   ld (hl),a
        inc hl
        inc a
        djnz .col
        ld hl,relax_cols
        ld b,12
        call shuffle
        call rnd
        and 3
        add a,5
        ld (relax_ncol),a
        ld b,a                  ; κάθε χρώμα 4 φορές
        ld hl,relax_cols
        ld de,relax_pool
.pool:  ld a,(hl)
        inc hl
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        inc de
        djnz .pool
.again: ld a,(relax_ncol)
        add a,a
        add a,a
        ld b,a
        ld hl,relax_pool
        call shuffle
        ld a,(relax_ncol)       ; κανένα μπουκάλι μονόχρωμο από την αρχή
        ld b,a
        ld hl,relax_pool
.uni:   ld a,(hl)
        ld c,0                  ; C = πόσες στρώσεις διαφέρουν από την 1η
        ld e,3
.uni2:  inc hl
        cp (hl)
        jr z,.same
        inc c
.same:  dec e
        jr nz,.uni2
        inc hl
        inc c
        dec c
        jr z,.again
        djnz .uni

        ld de,level_buf         ; header: flags, μπουκάλια, cap, όριο, χρόνος, par
        ld a,LF_EXTRA
        ld (de),a
        inc de
        ld a,(relax_ncol)
        add a,2
        ld (de),a
        inc de
        ld a,4
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld hl,relax_pool
        ld a,(relax_ncol)
        ld b,a
.bot:   call .head              ; bflags (cap), πάγος, λουκέτο, πλήθος
        ld a,4
        ld (de),a
        inc de
        push bc
        ld bc,4
        ldir
        pop bc
        djnz .bot
        call .head              ; και δύο άδεια
        xor a
        ld (de),a
        inc de
        call .head
        xor a
        ld (de),a
        ret
.head:  ld a,4
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        ret

; Ανακάτεμα Fisher-Yates. in: HL = πίνακας, B = μήκος (2..255).
shuffle:
        dec b
.i:     push hl
        push bc
        call rnd                ; A = τυχαίο, j = A mod (i+1)
        pop bc
        ld c,b
        inc c
.mod:   sub c
        jr nc,.mod
        add a,c
        pop hl
        push hl
        ld e,a
        ld d,0
        add hl,de
        ex de,hl                ; DE -> a[j]
        pop hl
        push hl
        ld a,l
        add a,b
        ld l,a
        jr nc,.ai
        inc h                   ; HL -> a[i]
.ai:    ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        pop hl
        djnz .i
        ret
