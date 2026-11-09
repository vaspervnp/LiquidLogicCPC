; disc.asm — η πρόοδος (ξεκλείδωτες πίστες + αστέρια) στη δισκέτα, LIQUID.SAV
;
; Μέσα από το AMSDOS, δηλαδή το firmware, που το παιχνίδι κρατάει κλειστό:
;   - στην εκκίνηση (load_progress) το firmware είναι ακόμα ζωντανό από το RUN
;   - για την αποθήκευση (save_progress) το fw_enter το ξαναζωντανεύει: τα
;     vectors του #0000-#003F (αντίγραφο στην εκκίνηση) και interrupts, και
;     stack στο #C000· όσο τρέχει, η lower ROM σκεπάζει το #0000-#3FFF, γι' αυτό
;     δεδομένα και όνομα περνάνε από το SAVE_BUF / NAME_BUF. Το fw_exit
;     ξαναβάζει τα δικά μας (interrupt του ήχου, mode, παλέτα) και σβήνει το
;     μοτέρ του drive.
; Τα μηνύματα του AMSDOS είναι κλειστά (#BE78): σε λάθος (χωρίς δισκέτα,
; προστασία εγγραφής) απλώς δεν αποθηκεύεται τίποτα.

CAS_IN_OPEN     equ #BC77
CAS_IN_CLOSE    equ #BC7A
CAS_IN_DIRECT   equ #BC83
CAS_OUT_OPEN    equ #BC8C
CAS_OUT_CLOSE   equ #BC8F
CAS_OUT_DIRECT  equ #BC98
AMSDOS_MSG      equ #BE78           ; #FF = χωρίς μηνύματα λάθους
KL_INIT_BACK    equ #BCCE
AMSDOS_ROM      equ 7
FDC_MOTOR       equ #FA7E
FW_STACK        equ #C000
FILE_BUF        equ #4000           ; 2K buffer του AMSDOS (RAM, config C0)
SAVE_BUF        equ #4800
SAVE_SIZE       equ 1+MAX_LEVELS    ; unlocked + stars (συνεχόμενα στο main.asm)
NAME_BUF        equ SAVE_BUF+#100   ; και το όνομα: ό,τι διαβάζει το AMSDOS
                                    ; πρέπει να είναι πάνω από το #4000

; Στην εκκίνηση, με το firmware ακόμα ενεργό. Το RUN"LIQUID.BIN" αφήνει το
; firmware χωρίς το AMSDOS (τα CAS πάνε στην κασέτα): KL INIT BACK για τη ROM 7,
; με το workspace της στη συνηθισμένη θέση κάτω από το #AC00.
load_progress:
        ld c,AMSDOS_ROM
        ld de,#0040
        ld hl,#ABFF
        call KL_INIT_BACK
        ld a,#FF
        ld (AMSDOS_MSG),a
        call name_copy
        ld de,FILE_BUF
        call CAS_IN_OPEN
        jr nc,.none
        ld hl,SAVE_BUF
        call CAS_IN_DIRECT
        push af
        call CAS_IN_CLOSE
        pop af
        jr nc,.none
        ld a,(SAVE_BUF)             ; έγκυρο unlocked: 1..MAX_LEVELS
        or a
        jr z,.none
        cp MAX_LEVELS+1
        jr nc,.none
        ld hl,SAVE_BUF
        ld de,unlocked
        ld bc,SAVE_SIZE
        ldir
.none:  ld bc,FDC_MOTOR
        xor a
        out (c),a
        ret

; Μετά από κάθε νίκη. Μερικές δεκάδες καρέ χωρίς ήχο/κίνηση.
save_progress:
        ld hl,unlocked
        ld de,SAVE_BUF
        ld bc,SAVE_SIZE
        ldir
        call name_copy
        call fw_enter
        ld hl,NAME_BUF
        ld b,SAVE_NAME_LEN
        ld de,FILE_BUF
        call CAS_OUT_OPEN
        jr nc,.done
        ld hl,SAVE_BUF
        ld de,SAVE_SIZE
        ld bc,0
        ld a,2                      ; binary
        call CAS_OUT_DIRECT
        call CAS_OUT_CLOSE
.done:  call fw_exit                ; (call: το fw_exit γυρίζει στο δικό μας stack)
        ret

; Το firmware ξανά ενεργό. Καλείται με τα δικά μας interrupts.
fw_enter:
        di
        pop hl                      ; η επιστροφή, γιατί αλλάζει το stack
        ld (fw_sp),sp
        ld sp,FW_STACK
        push hl
        xor a                       ; σιγή: ο ήχος μας σταματάει ως το fw_exit
.mute:  ld e,0
        push af
        add a,8
        call psg_write
        pop af
        inc a
        cp 3
        jr nz,.mute
        ld hl,fw_low
        ld de,0
        ld bc,64
        ldir
        ld a,#FF
        ld (AMSDOS_MSG),a
        ei
        ; Το AMSDOS πιστεύει ότι το μοτέρ είναι ακόμα αναμμένο (το σβήσαμε εμείς
        ; πίσω από την πλάτη του, χωρίς τον χρονοδιακόπτη του): το ανάβουμε και
        ; περιμένουμε ~1 s να πάρει στροφές, αλλιώς «drive not ready» (#C8).
        ld bc,FDC_MOTOR
        ld a,1
        out (c),a
        ld b,0                      ; 256 + 44 interrupts των 300 Hz
.spin:  halt
        djnz .spin
        ld b,44
.spin2: halt
        djnz .spin2
        ret

fw_exit:
        di
        pop hl
        ld sp,(fw_sp)
        push hl
        ld a,#C3                    ; JP int_handler στο #38
        ld (#38),a
        ld hl,int_handler
        ld (#39),hl
        ld bc,FDC_MOTOR
        xor a
        out (c),a
        ld bc,#7F00+GA_RAM_C0
        out (c),c
        ld bc,#7F00+GA_MODE0
        out (c),c
        call set_palette            ; το firmware έβαλε τα δικά του inks
        ld a,7                      ; και ο mixer του AY
        ld e,MIX_TONES
        call psg_write
        ei
        ret

; HL = NAME_BUF, B = μήκος του ονόματος.
name_copy:
        ld hl,save_name
        ld de,NAME_BUF
        ld bc,SAVE_NAME_LEN
        ldir
        ld hl,NAME_BUF
        ld b,SAVE_NAME_LEN
        ret

save_name:      db "LIQUID.SAV"
SAVE_NAME_LEN   equ $-save_name
