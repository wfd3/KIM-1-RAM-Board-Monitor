.include "../include/kim1_rom.s"

; Choose the start up monitor.  If no selected, will default to the KIM-1 monitor
START_XKIM 		= true
START_WOZMON	= false
START_BASIC		= false

;=====================================================
; Bring the KIM-1 up in TTY mode with the baud rate 
; hardwired to 1200 bps.  
.segment "TRAMP"

MYRESET:
		ldx #$FF 		    		; Init the stack
		txs
		stx SPUSER
		jsr INITS		    		; Init the KIM-1 hw
		lda #$00		    		; Set the baud rate to 1200
		sta CNTH30
		lda #$38
		sta CNTL30
		jsr INIT1		

		; Start the monitor
.if START_XKIM = true
		jmp XKIM_START

.elseif START_WOZMON = true
		jmp WOZMON_START

.elseif START_BASIC = true
		jmp MSBASIC_START

.else	; KIM-1 Monitor
		jmp KIM1_START
.endif 
