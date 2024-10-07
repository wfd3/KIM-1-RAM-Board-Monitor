# Variables
AS = ca65
LD = ld65
ASM_SRC = xKIM.s
ASM_INC = ptpload.s ../include/kim1_rom.s
OBJ = xKIM.o

# Targets
all: $(OBJ)

$(OBJ): $(ASM_SRC) $(ASM_INC)
	$(AS) -o $(OBJ) $(ASM_SRC)

# Clean up generated files
clean:
	rm -f $(OBJ) $(MAP) $(LBL)

.PHONY: all clean
