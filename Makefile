# Liquid Logic — build
#
#   make            build/LiquidLogic.dsk (Extended DSK)
#   make assets     ξαναπαράγει τα assets/data (γραφικά, πίνακες, πίστες)
#   make shot       headless emulator (~/cpcemu) -> build/screenshot.png
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

.PHONY: all assets shot test sound clean

all: $(DSK)

# Το rasm γράφει το LIQUID.BIN και το LEVELS.BIN σε νέα EDSK· το iDSK
# προσθέτει τον loader (κρατώντας το Extended format) και ελέγχουμε το header
# στο τέλος. Ο loader φορτώνει το LEVELS.BIN κατευθείαν στο bank 4.
$(DSK): $(SRC) $(DATA) Makefile
	@mkdir -p $(BUILD)
	rm -f $@
	$(RASM) -I src -I assets/data src/main.asm -o $(BUILD)/liquid -s -sq -os $(BUILD)/liquid.sym
	printf '10 MEMORY &3FFF:MODE 0:BORDER 0:OUT &7F00,&C4:LOAD"LEVELS.BIN":OUT &7F00,&C0:RUN"LIQUID.BIN"\r\n' > $(LOADER)
	$(IDSK) $@ -i $(LOADER) -t 0 > /dev/null 2>&1
	@head -c 21 $@ | grep -q 'EXTENDED CPC DSK File' || { echo "$@: δεν είναι Extended DSK"; exit 1; }
	@$(IDSK) $@ -l 2>/dev/null | grep -E '^[A-Z0-9 ]{8}\.'

assets/data/gfx.asm assets/data/physics.asm: assets/src/make_gfx.py
	$(PYTHON) assets/src/make_gfx.py

assets/data/sound_data.asm: assets/src/make_sound.py
	$(PYTHON) assets/src/make_sound.py

assets/data/levels.asm: tools/levels.py   # (και levels.json, για τα tests)
	$(PYTHON) tools/levels.py

assets:
	$(PYTHON) assets/src/make_gfx.py
	$(PYTHON) assets/src/make_sound.py
	$(PYTHON) tools/levels.py

shot: $(DSK)
	$(PYTHON) tools/headless.py shot

test: $(DSK)
	$(PYTHON) tools/headless.py test

sound: $(DSK)
	$(PYTHON) tools/sound_wav.py

clean:
	rm -rf $(BUILD)
