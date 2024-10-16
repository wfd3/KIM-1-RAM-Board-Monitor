
# Variables
AS = ca65
AS_OPTS = 
LD = ld65

OBJ = xKIM/xKIM.o MSBasic/kb9rom.o wozmon/wozmon.o trampoline/trampoline.o intvectors/intvectors.o
CFG = KIM64K.cfg
BIN = KIM64K.bin
MAP = KIM64K.map
LBL = KIM64K.lbl
#DEVICE = AT28C64B
DEVICE =  M27128A@DIP28

# Build everything: Ensure subdirectories and object files are built before linking
$(BIN): $(CFG) subdirs
	$(LD) -v -C $(CFG) -o $(BIN) -Ln $(LBL) -m $(MAP) $(OBJ)

.PHONY: all
all: $(BIN)

# Clean everything
.PHONY: clean
clean:
	for obj in $(OBJ); do \
		dir=$$(dirname $$obj); \
		$(MAKE) -C $$dir clean; \
	done
	rm -f $(BIN) $(MAP) $(LBL)

# Build all the subdirs
.PHONY: subdirs
subdirs:
	for obj in $(OBJ); do \
		dir=$$(dirname $$obj); \
		$(MAKE) -C $$dir AS=$(AS) AS_OPTS=$(AS_OPTS) LD=$(LD) all || exit 1; \
	done

# Burn the binary to the ROM
burn:
	minipro -p $(DEVICE) -w $(BIN)
