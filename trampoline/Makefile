# Variables
AS = ca65
LD = ld65
ASM_SRC = trampoline.s
ASM_INC = ../include/kim1_rom.s 
OBJ = trampoline.o
CUSTOM_BRINGUP = "CUSTOM_BRINGUP=1"

# Targets
all: $(OBJ)

# Assemble xKIM.asm to xKIM.o
$(OBJ): $(ASM_SRC) $(ASM_INC)
	$(AS) -o $(OBJ) -D$(CUSTOM_BRINGUP) $(ASM_SRC)

# Clean up generated files
clean:
	rm -f $(OBJ) $(MAP) $(LBL)

.PHONY: all clean
