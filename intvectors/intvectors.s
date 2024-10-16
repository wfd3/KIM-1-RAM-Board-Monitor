;=====================================================
; 6502 reset vectors
;
.include "../include/kim1_rom.s"
.export NMI
.export RESET
.export IRQ

.segment "VECS"
NMI:
		.word NMIT				; in KIM rom
RESET:
		.word TRAMPOLINE	 	; in external rom
IRQ:
		.word IRQT				; in KIM rom
.END
