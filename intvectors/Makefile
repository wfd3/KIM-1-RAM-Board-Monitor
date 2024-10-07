# Variables
AS = ca65
LD = ld65
ASM_SRC = intvectors.s
ASM_INC = ../include/kim1_rom.s 
OBJ = intvectors.o

# Targets
all: $(OBJ)

$(OBJ): $(ASM_SRC) $(ASM_INC)
	$(AS) -o $(OBJ) $(ASM_SRC)

# Clean up generated files
clean:
	rm -f $(OBJ) $(MAP) $(LBL)

.PHONY: all clean
