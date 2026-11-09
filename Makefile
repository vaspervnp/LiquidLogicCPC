# Liquid Logic — build
#
#   make            build/LiquidLogic.dsk (Extended DSK)
#   make assets     ξαναπαράγει τα assets/data από το assets/src
#   make shot       headless emulator (~/cpcemu) -> build/screenshot.png
#   make test       headless: μετάγγιση με τα πλήκτρα -> build/test_*.png
#   make clean

RASM     ?= rasm
IDSK     ?= iDSK
PYTHON   ?= python3

BUILD    := build
DSK      := $(BUILD)/LiquidLogic.dsk
LOADER   := $(BUILD)/disc.bas

SRC      := $(wildcard src/*.asm)
DATA     := assets/data/gfx.asm assets/data/physics.asm

.PHONY: all assets shot test clean

all: $(DSK)

# Το rasm γράφει το LIQUID.BIN σε νέα EDSK· το iDSK προσθέτει τον loader
# (κρατώντας το Extended format) και ελέγχουμε το header στο τέλος.
$(DSK): $(SRC) $(DATA) Makefile
	@mkdir -p $(BUILD)
	rm -f $@
	$(RASM) -I src -I assets/data src/main.asm -o $(BUILD)/liquid -s -sq -os $(BUILD)/liquid.sym
	printf '10 MODE 0:BORDER 0:RUN"LIQUID.BIN"\r\n' > $(LOADER)
	$(IDSK) $@ -i $(LOADER) -t 0 > /dev/null 2>&1
	@head -c 21 $@ | grep -q 'EXTENDED CPC DSK File' || { echo "$@: δεν είναι Extended DSK"; exit 1; }
	@$(IDSK) $@ -l 2>/dev/null | grep -E '^[A-Z0-9 ]{8}\.'

$(DATA): assets/src/make_gfx.py
	$(PYTHON) assets/src/make_gfx.py

assets:
	$(PYTHON) assets/src/make_gfx.py

shot: $(DSK)
	$(PYTHON) tools/headless.py shot

test: $(DSK)
	$(PYTHON) tools/headless.py test

clean:
	rm -rf $(BUILD)
