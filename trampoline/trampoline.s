.include "../include/kim1_rom.s"
.import XKIM_MONITOR
.import WOZMON
.import MSBASIC_START

;=====================================================
; Bring the KIM-1 up in TTY mode with the baud rate 
; hardwired to 1200 bps.  
.segment "TRAMP"
.if CUSTOM_BRINGUP
.export MYRESET
MYRESET:
		ldx #$FF 		    ; Init the stack
		txs
		stx SPUSER
		jsr INITS		    ; Init the KIM-1 hw
		lda #$00		    ; Set the baud rate to 1200
		sta CNTH30
		lda #$38
		sta CNTL30
		jsr INIT1		
		jmp XKIM_MONITOR    ; xKIM Monitor
;		jmp SHOW1		    ; KIM-1 Monitor
;		jmp WOZMON		    ; Wozmon Apple 1 Monitor
; 		jmp MSBASIC_START   ; MS Basic
.endif
