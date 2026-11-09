; sound_data.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_sound.py, μην το αλλάζεις με το χέρι

MUSIC_STEP      equ 7

; περίοδοι τόνου για τις νότες 0..72 (0 = παύση, 1 = C1)
note_table:
        dw 0,1911,1804,1703,1607,1517,1432,1351,1276,1204,1136,1073
        dw 1012,956,902,851,804,758,716,676,638,602,568,536
        dw 506,478,451,426,402,379,358,338,319,301,284,268
        dw 253,239,225,213,201,190,179,169,159,150,142,134
        dw 127,119,113,106,100,95,89,84,80,75,71,67
        dw 63,60,56,53,50,47,45,42,40,38,36,34
        dw 32

sfx_select:
        dw #0068
        db 12
        dw #0053
        db 11
        dw #0042
        db 9
        dw #0034
        db 8
        dw 0
        db #FF

sfx_cancel:
        dw #0045
        db 10
        dw #0057
        db 8
        dw #006E
        db 7
        dw #008B
        db 5
        dw 0
        db #FF

sfx_error:
        dw #0259
        db 13
        dw #0238
        db 12
        dw #0259
        db 11
        dw #0238
        db 10
        dw #0259
        db 9
        dw #0238
        db 8
        dw #0259
        db 7
        dw #0238
        db 6
        dw #0259
        db 5
        dw #0238
        db 4
        dw 0
        db #FF

sfx_cork:
        dw #8006
        db 14
        dw #8003
        db 11
        dw #002D
        db 12
        dw #002A
        db 10
        dw #0027
        db 8
        dw #0025
        db 6
        dw #0023
        db 4
        dw 0
        db #FF

sfx_win:
        dw #0077
        db 13
        dw #0077
        db 12
        dw #0077
        db 11
        dw #0077
        db 10
        dw #0077
        db 9
        dw #005F
        db 13
        dw #005F
        db 12
        dw #005F
        db 11
        dw #005F
        db 10
        dw #005F
        db 9
        dw #0050
        db 13
        dw #0050
        db 12
        dw #0050
        db 11
        dw #0050
        db 10
        dw #0050
        db 9
        dw #003C
        db 13
        dw #003C
        db 12
        dw #003C
        db 11
        dw #003C
        db 10
        dw #003C
        db 9
        dw #002F
        db 13
        dw #002F
        db 12
        dw #002F
        db 11
        dw #002F
        db 10
        dw #002F
        db 9
        dw #002F
        db 8
        dw #002F
        db 7
        dw #002F
        db 6
        dw #002F
        db 5
        dw #002F
        db 4
        dw #002F
        db 3
        dw #002F
        db 2
        dw 0
        db #FF

sfx_chime:
        dw #0050
        db 12
        dw #0050
        db 10
        dw #0050
        db 8
        dw #0050
        db 6
        dw #0050
        db 4
        dw #0050
        db 2
        dw #0035
        db 12
        dw #0035
        db 10
        dw #0035
        db 8
        dw #0035
        db 6
        dw #0035
        db 4
        dw #0035
        db 2
        dw 0
        db #FF

sfx_undo:
        dw #003E
        db 11
        dw #004A
        db 10
        dw #0058
        db 8
        dw #0069
        db 7
        dw #007D
        db 6
        dw 0
        db #FF

sfx_extra:
        dw #00D0
        db 13
        dw #00B8
        db 12
        dw #00A3
        db 12
        dw #0090
        db 11
        dw #0080
        db 11
        dw #0071
        db 10
        dw #0064
        db 10
        dw #0059
        db 9
        dw #004E
        db 9
        dw #0045
        db 8
        dw 0
        db #FF

sfx_timeup:
        dw #00BE
        db 13
        dw #00BE
        db 12
        dw #00BE
        db 11
        dw #00BE
        db 10
        dw #00BE
        db 9
        dw #00BE
        db 8
        dw #00BE
        db 7
        dw #00D5
        db 13
        dw #00D5
        db 12
        dw #00D5
        db 11
        dw #00D5
        db 10
        dw #00D5
        db 9
        dw #00D5
        db 8
        dw #00D5
        db 7
        dw #00EF
        db 13
        dw #00EF
        db 12
        dw #00EF
        db 11
        dw #00EF
        db 10
        dw #00EF
        db 9
        dw #00EF
        db 8
        dw #00EF
        db 7
        dw #011C
        db 13
        dw #011C
        db 12
        dw #011C
        db 11
        dw #011C
        db 10
        dw #011C
        db 9
        dw #011C
        db 8
        dw #011C
        db 7
        dw 0
        db #FF

sfx_tick:
        dw #001F
        db 9
        dw #001F
        db 4
        dw 0
        db #FF

; μελωδία του τίτλου (κανάλι A): νότα, καρέ
music_a:
        db 53,7    ; E5
        db 56,7    ; G5
        db 58,14    ; A5
        db 56,7    ; G5
        db 53,7    ; E5
        db 51,14    ; D5
        db 49,7    ; C5
        db 51,7    ; D5
        db 53,14    ; E5
        db 46,28    ; A4
        db 49,7    ; C5
        db 53,7    ; E5
        db 56,14    ; G5
        db 58,7    ; A5
        db 56,7    ; G5
        db 53,14    ; E5
        db 51,7    ; D5
        db 49,7    ; C5
        db 51,14    ; D5
        db 53,28    ; E5
        db 58,7    ; A5
        db 56,7    ; G5
        db 53,14    ; E5
        db 56,7    ; G5
        db 53,7    ; E5
        db 51,14    ; D5
        db 49,7    ; C5
        db 51,7    ; D5
        db 53,14    ; E5
        db 44,28    ; G4
        db 46,7    ; A4
        db 49,7    ; C5
        db 53,14    ; E5
        db 51,7    ; D5
        db 49,7    ; C5
        db 48,14    ; B4
        db 49,14    ; C5
        db 48,14    ; B4
        db 46,28    ; A4
        db #FF

; μπάσο (κανάλι C)
music_c:
        db 22,28    ; A2
        db 18,28    ; F2
        db 25,28    ; C3
        db 20,28    ; G2
        db 22,28    ; A2
        db 18,28    ; F2
        db 20,28    ; G2
        db 25,28    ; C3
        db 18,28    ; F2
        db 20,28    ; G2
        db 25,28    ; C3
        db 22,28    ; A2
        db 18,28    ; F2
        db 20,28    ; G2
        db 17,28    ; E2
        db 22,28    ; A2
        db #FF
