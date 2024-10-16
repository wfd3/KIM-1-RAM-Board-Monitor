# Define source and object files
SRC = msbasic.s 
OBJ = kb9rom.o
INCLUDES = array.s chrget.s defines_kimrom.s defines_kim.s defines.s error.s eval.s extra.s \
		   float.s flow1.s flow2.s header.s init.s inline.s input.s iscntc.s kim_extra.s \
		   kim_iscntc.s kim_loadsave.s kimrom_extra.s loadsave.s macros.s memory.s message.s \
		   misc1.s misc2.s misc3.s poke.s print.s program.s rnd.s string.s token.s trig.s var.s zeropage.s 
TARGET_BOARD = kb9rom

ASFLAGS = -D $(TARGET_BOARD)

# The default target
.PHONY: all
all: $(OBJ)

# Rule to assemble .s to .o
$(OBJ): $(SRC) $(INCLUDES)
	$(AS) $(AS_OPTS) $(ASFLAGS) -o $@ $<

# Clean target
.PHONY: clean
clean:
	rm -f $(OBJ)
