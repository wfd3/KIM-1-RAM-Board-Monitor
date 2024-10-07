;=====================================================
; 6502 reset vectors
;
.include "../include/kim1_rom.s"
.import MYRESET

.segment "VECS"
NMI:
		.word NMIT		;in KIM rom
RESET:
	.if CUSTOM_BRINGUP
		.word MYRESET 	;in external rom
	.else
		.word RST		;in KIM rom
	.endif
IRQ:
		.word IRQT		;in KIM rom
.END
