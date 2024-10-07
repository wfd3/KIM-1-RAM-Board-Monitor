# Variables
AS = ca65
LD = ld65

SUBDIRS := xKIM MSBasic wozmon trampoline intvectors
OBJ = xKIM/xKIM.o MSBasic/kb9rom.o wozmon/wozmon.o trampoline/trampoline.o intvectors/intvectors.o
CFG = KIM64K.cfg
BIN = KIM64K.bin
MAP = KIM64K.map
LBL = KIM64K.lbl
#DEVICE = AT28C64B
DEVICE =  M27128A@DIP28

# Build everything: Ensure subdirectories and object files are built before linking
$(BIN): clean $(CFG) 
	$(MAKE) -C xKIM
	$(MAKE) -C MSBasic
	$(MAKE) -C wozmon
	$(MAKE) -C trampoline
	$(MAKE) -C intvectors
	$(LD) -v -C $(CFG) -o $(BIN) -Ln $(LBL) -m $(MAP) $(OBJ)

.PHONY: all
all: $(BIN)

# Clean everything
.PHONY: clean
clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	rm -f $(BIN) $(MAP) $(LBL)

# Burn the binary to the ROM
burn: $(BIN)
	minipro -p $(DEVICE) -w $(BIN)
