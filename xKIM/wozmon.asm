;		  
; EWoz Monitor KIM monitor version
; Hans Otten, 2024
;
; Modified to work on the KIM-1
;
; Idea and this version by Ronny Ribeiro, placed in the unused space in KIM tape ROM at $1AA0
; X command returns to KIM monitor
;
; Based upon a version by Jim McClanahan, W4JBM, April 2021
;
; Based on EWoz 1.0 by fsafstrom, March 2007. Relevant notes from original:
;
; The EWoz 1.0 is just the good old Woz mon with a few improvements and extensions so to say.
;
; It prints a small welcome message when started.
; All key strokes are converted to uppercase.
; The backspace works so the _ is no longer needed.
; When you run a program, it's called with an jsr so if the program ends
;   with an rts, you will be taken back to the monitor.
;
; Also incorporated some changes from the Glitch Works and TangentDelta
; version created for the R65x1Q sbc.
;
; Notes for this version (1.0P as in 'PAL-1'):
;
; Currently designed to load into RAM.
; Makes use of I/O routines in the KIM-1's ROM.
; May clobber Page Zero locations used by other applications, so you should
;   probably cold start anything else like the original monitor.
; By default, the original KIM-1 echoes all input. This uses a hardware 'trick'
;   to add some flexibility, but it is still limited to 'blocking' input. In
;   other words, there is no way to check if a key has been pressed--instead you
;   go to read a key and wait until one is pressed before returning.
;		  
; KIM-1 monitor
;		  
; Get the KIM-1 ROM addresses
.include "../include/kim1_rom.s"
;
KIMMON		= 	START  				; KIM ROM monitor start
CORSHAM     =   extKim				; Corsham xKIM monitor start
;
; KIM Hardware addresses used
;
;
; eWoz Page Zero Usage
; 
XAML	= 	$E5				; start at free space in upper zero page
XAMH	= 	XAML + 1
STL		= 	XAMH + 1
STH		= 	STL + 1
L		= 	STH + 1
H		= 	L + 1
YSAV	= 	H + 1
WMODE	= 	YSAV + 1
COUNTR	= 	WMODE + 1
SADDR   = 	COUNTR+1  			

; 


;
; input buffer
;
;IN		= 	$0300
.import IN

.segment "WOZMON"

.export WOZMON
WOZMON: 	cld					; Clear decimal			
     		ldx 	#$FF		; Clear stack
     		txs
SFTRST:		lda 	#ESC		; Load Escape key
NOTCR:		cmp 	#BS			; was it backspace?
     		beq 	BCKSPC		; Yes.
     		cmp 	#ESC		; escape?
     		beq 	ESCAPE		; Yes
     		iny					; increment buffer index
     		bpl 	NXTCHR		; auto escape if buffer > 127?
ESCAPE:		lda 	#BACKSL		; show \
     		jsr 	ECHO		; Output it
GETLIN:		jsr 	OUTCRLF		; print CRLF
     		ldy 	#$01		; initialize buffer index
BCKSPC:		dey					; backspacing
     		bmi 	GETLIN		; too far start again
     		lda 	#SPC		; overwrite 
     		jsr 	ECHO
     		lda 	#BS			; and BS again
     		jsr 	ECHO
NXTCHR:		jsr 	GETKEY		; get next char
			cmp 	#ESC
			beq 	ESCAPE
     		cmp 	#$60
     		bmi 	CNVRT
     		and 	#$5F		; convert to uppercase
CNVRT:		sta 	IN,y		; add to buffer
     		jsr 	ECHO		; and show on screen
     		cmp 	#CR			; CR?
     		bne 	NOTCR
     		ldy 	#$FF		; reset text index
     		lda 	#$00
     		tax
SETSTR:		asl		a
SETMOD:		sta 	WMODE
BLSKIP:		iny
NXTITM:		lda 	IN,y
     		cmp 	#CR			; CR?
     		beq		GETLIN
     		cmp 	#DOT		; . ?
     		bcc 	BLSKIP
     		beq 	SETMOD
     		cmp 	#COLON		; : ?
     		beq 	SETSTR		; store mode
     		cmp 	#'R'		; R?
     		beq 	RUN			; run user program
     		cmp 	#'X'		; X? 
     		beq 	XKIM		; back to KIM monitor
			cmp		#'C'		; C?
			beq		CKIM		; back to Corsham monitor
     		stx 	L			; clear L H
     		stx 	H
     		sty 	YSAV
NXTHEX:		lda 	IN,y
     		eor 	#$30		; map digits 0-9
     		cmp 	#$0A		; digit?
     		bcc 	DIG
     		adc 	#$88		; map letter A_F to FA - FF
     		cmp 	#$FA		; hex character?
     		bcc 	NOTHEX		; not hex
DIG:		asl 	a
     		asl 	a			; hex digit to MSD of A
     		asl 	a
     		asl 	a
     		ldx 	#$04		; shift count
HEXSFT:		asl 	a			; hex digit left MSB to carry
     		rol 	L
     		rol 	H			; rotate in LSD MSD
     		dex
     		bne 	HEXSFT
     		iny
     		bne 	NXTHEX		; loop 4
NOTHEX:		cpy 	YSAV
     		bne 	NOESC
     		jmp 	SFTRST		; reset EWOZ
XKIM:		jmp 	KIMMON		; start KIM monitor
CKIM:		jmp		CORSHAM
RUN:		jsr 	RUNU	
     		jmp 	SFTRST
RUNU:		jmp 	(XAML)
;
NOESC:		bit 	WMODE		; test WMODE
     		bvc 	NOTSTR		; bit 6 = 0 for stoe, 1 for XAM and block XAM
     		lda 	L
     		sta 	(STL,x)		; current store address
     		inc 	STL	
     		bne 	NXTITM		; next item
     		inc 	STH
TONXIT:		jmp 	NXTITM
;
NOTSTR:		lda 	WMODE
     		cmp 	#DOT
     		beq 	XAMNXT
     		ldx 	#$02
SETADR:		lda 	L-1,x		; copy hex data store index
     		sta 	STL-1,x
     		sta 	XAML-1,x
     		dex					; next 2 bytes
     		bne 	SETADR
NXTPRN:		bne 	PRDATA
     		jsr 	OUTCRLF
     		lda 	XAMH		; output in hex data
     		jsr 	PRBYTE
     		lda 	XAML
     		jsr 	PRBYTE
     		lda 	#COLON
     		jsr 	ECHO
PRDATA:		lda 	#SPC
     		jsr 	ECHO
     		lda 	(XAML,x)	; output hex
     		jsr 	PRBYTE
XAMNXT:		stx 	WMODE
     		lda 	XAML		; compare index
     		cmp L
     		lda XAMH
     		sbc H
     		bcs TONXIT
     		inc XAML
     		bne MD8CHK			; increment examine index
     		inc		XAMH		; was - inc $31
MD8CHK:		lda		XAML		; was - lda $30
     		and #$07			; was - and #$0F
     		bpl NXTPRN
PRBYTE:		pha					; save A for LSD
     		lsr a
     		lsr a
     		lsr a
     		lsr a
     		jsr PRHEX			; ouput hex digit			
     		pla
PRHEX:		and #$0F
     		ora #'0'
     		cmp #$3A			; digit?
               bcc ECHO
     		adc #$06			; offset for hex char
ECHO:		sta SADDR
     		tya
     		sta SADDR+1
     		lda SADDR
     		and #$7F
     		jsr OUTCH			; strip upper bit
     		lda SADDR+1
     		tay
     		lda SADDR
     		rts
;
;	KIM-1 GETCH routine with echo suppression
;			
			
GETKEY:		tya
     		sta SADDR+1			; save Y
     		lda SBD				; mask lowbit
     		and #$FE			
     		sta SBD			 	; set echo port to block
     		jsr GETCH			; KIM GETCH in A, Y changed
     		sta SADDR
     		lda SBD				; clear echo port
     		ora #$01
     		sta SBD
     		lda SADDR+1			; restore Y
     		tay
     		lda SADDR			; restore read character
     		rts
;
; Print CR and LF 
;
OUTCRLF:	tya					; print CRLF. saves Y
     		sta SADDR+1			; save Y
     		lda #CR
     		jsr OUTCH
     		lda #LF
     		jsr OUTCH
     		lda SADDR+1			; restore Y
     		tay
     		rts
