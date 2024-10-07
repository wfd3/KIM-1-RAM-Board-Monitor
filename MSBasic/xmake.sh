if [ ! -d tmp ]; then
	mkdir tmp
fi

ld65 -v -C kb9xrom.cfg tmp/kb9rom.o tmp/xKIM.o -o tmp/kb9xrom.bin -Ln tmp/kb9xrom.lbl -m tmp/kb9xrom.map


