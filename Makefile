# Liquid Logic — build
#
#   make            build/LiquidLogic.dsk (Extended DSK)
#   make assets     ξαναπαράγει τα assets/data (γραφικά, πίνακες, πίστες)
#   make shot       headless emulator (~/cpcemu) -> build/screenshot.png
#   make shot32     Caprice32 χωρίς παράθυρο: τίτλος και πίστα 1 -> build/cap32_*.png
#   make test       headless: λύνει πίστες με τα πλήκτρα, undo -> build/test_*.png
#   make sound      headless: οι registers του AY -> build/sound_*.wav
#   make clean

RASM     ?= rasm
IDSK     ?= iDSK
PYTHON   ?= python3

BUILD    := build
DSK      := $(BUILD)/LiquidLogic.dsk
LOADER   := $(BUILD)/disc.bas

SRC      := $(wildcard src/*.asm)
DATA     := assets/data/gfx.asm assets/data/physics.asm assets/data/levels.asm assets/data/sound_data.asm
LOADSCR  := assets/data/loading.bin

.PHONY: all assets shot shot32 test sound clean

all: $(DSK)

# Το rasm γράφει το LIQUID.BIN, το EXTRA.BIN και το LEVELS.BIN σε νέα EDSK·
# το iDSK προσθέτει τον loader και την οθόνη φόρτωσης (κρατώντας το Extended
# format) και ελέγχουμε το header στο τέλος. Ο loader βάζει την παλέτα του
# παιχνιδιού, φορτώνει την οθόνη στο #C000, το LEVELS.BIN κατευθείαν στο
# bank 4, το EXTRA.BIN στο #4A00 και τρέχει το LIQUID.BIN.
$(DSK): $(SRC) $(DATA) $(LOADSCR) Makefile
	@mkdir -p $(BUILD)
	rm -f $@
	$(RASM) -I src -I assets/data src/main.asm -o $(BUILD)/liquid -s -sq -os $(BUILD)/liquid.sym
	printf '10 MODE 0:BORDER 0:FOR i=0 TO 15:READ c:INK i,c:NEXT:LOAD"SCREEN.BIN",&C000\r\n' > $(LOADER)
	printf '20 MEMORY &3FFF:OUT &7F00,&C4:LOAD"LEVELS.BIN":OUT &7F00,&C0:LOAD"EXTRA.BIN":RUN"LIQUID.BIN"\r\n' >> $(LOADER)
	printf '30 DATA %s\r\n' "$$(cat assets/data/loading_inks.txt)" >> $(LOADER)
	cp $(LOADSCR) $(BUILD)/screen.bin
	$(IDSK) $@ -i $(LOADER) -t 0 > /dev/null 2>&1
	$(IDSK) $@ -i $(BUILD)/screen.bin -t 1 -c C000 -e C000 > /dev/null 2>&1
	@head -c 21 $@ | grep -q 'EXTENDED CPC DSK File' || { echo "$@: δεν είναι Extended DSK"; exit 1; }
	@$(IDSK) $@ -l 2>/dev/null | grep -E '^[A-Z0-9 ]{8}\.'

assets/data/gfx.asm assets/data/physics.asm: assets/src/make_gfx.py
	$(PYTHON) assets/src/make_gfx.py

assets/data/loading.bin: assets/src/make_loading.py assets/src/make_gfx.py
	$(PYTHON) assets/src/make_loading.py

assets/data/sound_data.asm: assets/src/make_sound.py
	$(PYTHON) assets/src/make_sound.py

assets/data/levels.asm: tools/levels.py   # (και levels.json, για τα tests)
	$(PYTHON) tools/levels.py

assets:
	$(PYTHON) assets/src/make_gfx.py
	$(PYTHON) assets/src/make_sound.py
	$(PYTHON) assets/src/make_loading.py
	$(PYTHON) tools/levels.py

shot: $(DSK)
	$(PYTHON) tools/headless.py shot

shot32: $(DSK)
	tools/cap32_shot.sh $(DSK) $(BUILD)/cap32_title.png
	PAD=950 KEY=" " tools/cap32_shot.sh $(DSK) $(BUILD)/cap32_level1.png

test: $(DSK)
	$(PYTHON) tools/headless.py test

sound: $(DSK)
	$(PYTHON) tools/sound_wav.py

clean:
	rm -rf $(BUILD)
