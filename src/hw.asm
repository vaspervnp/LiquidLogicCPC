; hw.asm — υλικό: gate array, παλέτα, VSYNC, πληκτρολόγιο/joystick

GA_MODE0        equ #8C         ; gate array: mode 0, upper + lower ROM off
GA_RAM_C0       equ #C0         ; RAM config 0: τα 64K της κύριας μνήμης
GA_RAM_C4       equ #C4         ; RAM config 4: bank 4 στο #4000-#7FFF
PPI_B           equ #F5         ; PPI port B: bit 0 = VSYNC

; Η παλέτα (palette_hw, gfx.asm) στα 16 pens, και border = pen 0.
set_palette:
        ld hl,palette_hw
        ld bc,#7F00
.pen:   out (c),c               ; επιλογή pen
        ld a,(hl)
        inc hl
        out (c),a               ; hardware χρώμα
        inc c
        ld a,c
        cp 16
        jr nz,.pen
        ld c,#10                ; border
        out (c),c
        ld a,(palette_hw)
        out (c),a
        ret

; Περιμένει την αρχή του επόμενου VSYNC (με DI, χωρίς interrupts).
wait_vsync:
        ld b,PPI_B
.end:   in a,(c)                ; τέλος του τρέχοντος, αν είμαστε μέσα του
        rra
        jr c,.end
.start: in a,(c)
        rra
        jr nc,.start
        ret

;------------------------------------------------------------------
; Πληκτρολόγιο: οι 10 γραμμές του matrix στο keymap (0 = πατημένο). Περνάει
; από τον AY (reg 14, θύρα A του PPI σε είσοδο), οπότε με DI: ο ήχος του
; interrupt (sound.asm) γράφει κι αυτός στον AY.
read_keys:
        di
        ld hl,keymap
        ld bc,#F40E             ; PSG: επιλογή reg 14
        out (c),c
        ld bc,#F6C0             ; PSG: select register
        out (c),c
        xor a                   ; PSG: inactive
        out (c),a
        ld bc,#F792             ; PPI port A = είσοδος
        out (c),c
        ld a,#40                ; PSG read + γραμμή 0
.line:  ld b,#F6
        out (c),a
        ld b,#F4
        in e,(c)
        ld (hl),e
        inc hl
        inc a
        cp #4A
        jr nz,.line
        ld bc,#F782             ; PPI port A = έξοδος
        out (c),c
        ld bc,#F600             ; PSG: inactive
        out (c),c
        ei
        ret

; Ενέργειες του παίκτη, ένα bit η καθεμία.
IN_UP           equ 1
IN_DOWN         equ 2
IN_LEFT         equ 4
IN_RIGHT        equ 8
IN_FIRE         equ 16
IN_ESC          equ 32
IN_RESTART      equ 64
IN_UNDO         equ 128

; out: (input) = κρατημένα, (input_new) = όσα πατήθηκαν σε αυτό το καρέ·
; το ίδιο για τις ενέργειες IN2_* στο input2 / input2_new.
read_input:
        call read_keys
        ld hl,key_bindings2
        ld de,input2
        call map_keys
        ld hl,key_bindings
        ld de,input
; HL = αντιστοιχίσεις, DE = κρατημένα (και +1: νέα).
map_keys:
        ld c,0
.next:  ld a,(hl)               ; γραμμή
        cp #FF
        jr z,.done
        inc hl
        push de
        ld e,a
        ld d,0
        push hl
        ld hl,keymap
        add hl,de
        ld a,(hl)
        pop hl
        pop de
        and (hl)                ; bit του πλήκτρου: 0 = πατημένο
        inc hl
        jr nz,.up
        ld a,c
        or (hl)
        ld c,a
.up:    inc hl
        jr .next
.done:  ld a,(de)
        cpl
        and c
        inc de
        ld (de),a
        dec de
        ld a,c
        ld (de),a
        ret

; γραμμή, bit mask, ενέργεια
key_bindings:
        db 0,%00000001,IN_UP            ; κέρσορες
        db 0,%00000100,IN_DOWN
        db 1,%00000001,IN_LEFT
        db 0,%00000010,IN_RIGHT
        db 5,%10000000,IN_FIRE          ; SPACE
        db 8,%00000100,IN_ESC           ; ESC
        db 6,%00000100,IN_RESTART       ; R
        db 5,%00000100,IN_UNDO          ; U
        db 9,%00000001,IN_UP            ; joystick 0
        db 9,%00000010,IN_DOWN
        db 9,%00000100,IN_LEFT
        db 9,%00001000,IN_RIGHT
        db 9,%00010000,IN_FIRE
        db #FF

IN2_EXTRA       equ 1
IN2_MENU        equ 2

key_bindings2:
        db 7,%00000100,IN2_EXTRA        ; E
        db 4,%01000000,IN2_MENU         ; M
        db #FF

; xorshift 16-bit (John Metcalf). out: A = L = τυχαίο byte, HL = νέο seed.
rnd:
        ld hl,(rnd_seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rnd_seed),hl
        ld a,l
        ret
