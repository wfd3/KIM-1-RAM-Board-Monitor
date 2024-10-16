;*****************************************************
; Extended KIM monitor, written 2015 by Bob Applegate
; K2UT - bob@corshamtech.com
;
; This code was written as part of the Corsham Tech
; 60K RAM/EPROM board.  It provides a working area for
; an extended version of the KIM-1 monitor capabilities,
; mostly based on a TTY interface, not the keypad and
; hex display.
;
; This extensions contains an assortment of basic
; tools that are missing from the KIM-1's built in
; console monitor.  It has commands for loading hex
; files (as opposed to KIM format), accessing an SD
; card system, memory edit, hex dump, etc.  It also
; has the ability for user-defined extensions to be
; added.  And a number of common entry points have
; vectors so the monitor can be modified without
; breaking programs that use it.
;
; I'm not claiming copyright; I wrote most of this,
; but also borrowed from others (credit is given in
; those sections of code).  All of the portions I've
; written are free to use, but please keep my name
; in the comments somewhere.  Even better, consider
; buying a board from us: www.corshamtech.com
;
; 12/01/2015	Bob Applegate
;		Initial development - V0.X
; 03/15/2016	Bob Applegate
;		v1.0 - First official release
; 01/03/2017	Bob Applegate
;		v1.1 - Added S command
; 09/20/2018	Bob Applegate
;		v1.2 - Added auto-run vector
; 01/25/2019	Bob Applegate
;		v1.3 - Added 'X' command.
;		Added the 'C' command to get time.
; 03/09/2019	Bob Applegate
;		v1.4 - Added 'O' command.
; 07/26/2020	Bob Applegate
;		v1.5 - Fixed bug that caused the S
;		command to create empty file with no
;		contents.
;		Minor typo fixes.
;		Added CLD instructions.
; 11/14/2020	Bob Applegate
;		v1.6 - On SD error, display reason code.
; 09/15/2021	Bob Applegate
;		v1.7
;		Added offset calculator command O.
;		Added R command in Edit mode.
;		Removed '.' when loading from console.
; 09/20/2021	Bob Applegate
;		v1.8
;		Made a lot of the command handlers
;		into subroutines and added vectors so
;		external programs can call them.
;		Fixed bugs in Edit mode.
;
;*****************************************************
;
; Useful constants
;
; Intel HEX record types
;
DATA_RECORD	= 	$00
EOF_RECORD	= 	$01
;
; Max number of bytes per line for hex dump
;
BYTESLINE	= 	16
;
; Flag values used to detect a cold start vs warm
;
COLD_FLAG_1	= 	$19
COLD_FLAG_2	= 	$62
;
;=====================================================
; Memory bank 
; Which IO Port
BANK_PORT	= $1701 ; PADD
BANK_PIN	= $1
BANK_MASK	= $FE	; (BANK_PIN xor $FF)
;
;=====================================================
; KIM-1 ROM addresses
.include "../include/kim1_rom.s"
.import ECHO
.import GETKEY
;
;=====================================================
; Memory layout:
; We assume that the KIM-1 on-board ram from 0200-03FF is
; available for the monitor and Basic.  That leaves the
; external RAM from 2000-BFFF (or CFFF if using an 8K ROM)
; for Basic program space or other user programs.

.segment "XKIMDATA"

LowestAddress	= 	*
;
; Storage for registers for some monitor calls.
;
saveA:		.res 1
saveX:		.res 1
saveY:		.res 1
saveP:		.res  1
.export IN
IN:			.res 127
;
byteCount	= 	saveX
;
;
; Before loading a hex file, the MSB of this vector
; is set to FF.  After loading the file, if the MSB
; is no longer FF then the address in this vector is
; jumped to.  Ie, it can auto-run a file.
;
AutoRun:		.res 2
;
; ColdFlag is used to determine if the extended
; monitoring is doing a warm or cold start.
;
ColdFlag:	.res 2
;
; Address of a command table for user-created
; extensions to the monitor.
;
ExtensionAddr:	.res 2
;
; Save EAL/EAH
saveEAL:		.res 1
saveEAH:		.res 1
;
; Active RAM bank
;
;activeBank:		.res 1
;
; C000 ROM present?
; if 1, there's ROM mapped at C000-DFFF. if 0, RAM.
isROMAtC000:		.res 1

; This is the higest location in RAM usable by user
; programs.  Nobody should go past this address.  If
; you are writing extentions to the monitor, it's
; okay to load before the address and then adjust
; this down to keep others from stomping on your
; extention.
;
; If your program modifies this value, it needs to
; set it back before terminating.
;
HighestAddress:	.res 2
; 
;=====================================================
; Code starts at E000 and goes until FFFF, except for
; the 6502 vectors at the end of memory.  Add a segment
; to pad out the $0300 bytes if building without Basic
;
.segment "PADDING"

;
;=====================================================
; This is the start of the extended KIM monitor.
;
.segment "XKIM"

XKIM_MONITOR:
		jmp extKim
notty:		
		jmp	TTYKB
extKim:	
		ldx	#$ff
		txs
		lda	#$01	;see if in tty mode
		bit	SAD
		bne	notty	;branch if in keyboard mode
;
; Determine if this is a cold or warm start
;
		lda	ColdFlag
		cmp	#COLD_FLAG_1
		bne	coldStart
		lda	ColdFlag+1
		cmp	#COLD_FLAG_2
		bne	coldStart
		jmp	extKimLoop	;it's a warm start
;
; Cold start
;
coldStart:
		lda	#COLD_FLAG_1	;indicate we've done cold
		sta	ColdFlag
		lda	#COLD_FLAG_2
		sta	ColdFlag+1
;
; Point to an empty extension set by default.
;
;		lda	#defaultExt&$ff	;set extension pointers
;		sta	ExtensionAddr
;		lda	#defaultExt/256
;		sta	ExtensionAddr+1
;
; Set HighestAddress to just before our RAM area.
;
		lda	#.lobyte(LowestAddress-1)
		sta	HighestAddress
		lda	#.hibyte(LowestAddress-1)
		sta	HighestAddress+1
;
; Initialize the memory bank 
;
		jsr initBank
;
; Check ROM Mapping
;
		jsr checkForROM
;
; Clear the terminal
;
		jsr clearTerm
;
; Display our welcome text
;
		jsr	shortVersion
;
; Main command loop.  Put out prompt, get command, etc.
; Prints a slightly different prompt for the RAM version.
;
extKimLoop:	
		cld
		jsr	putsil		;output prompt
		.byte	CR,LF	;feel free to change it
		.byte	">",0
		jsr	xkimGetCH
		cmp	#CR
		beq	extKimLoop
		cmp	#LF
		beq	extKimLoop
		sta	ACC			;save key
;
; Now cycle through the list of commands looking for
; what the user just pressed.
;
		lda	#.lobyte(commandTable)
		sta	POINTL
		lda	#.hibyte(commandTable)
		sta	POINTH
		jsr	searchCmd	;try to find it
		bcc extKimLoop
;
; Hmmm... wasn't one of the built in commands, so
; see if it's an extended command.
;
;		lda	ExtensionAddr
;		sta	POINTL
;		lda	ExtensionAddr+1
;		sta	POINTH
;		jsr	searchCmd
		bcc cmdFound
;
; If that returns, then the command was not found.
; Print that it's unknown.
;
		jsr	putsil
		.asciiz " - Huh?"
cmdFound:
		jmp	extKimLoop
;
;=====================================================
; Vector table of commands.  Each entry consists of a
; single ASCII character (the command), a pointer to
; the function which handles the command, and a pointer
; to a string that describes the command.
;
commandTable:
		.byte '?'
		.word showHelp
		.word quesDesc
;
		.byte 'A'
		.word doAddresses
		.word aDesc
;
		.byte 'B'
		.word goBasic
		.word bDesc
;
		.byte 'C'
		.word doClearTerm
		.word cDesc
;
		.byte 'E'	;edit memory
		.word editMemory
		.word eDesc
;
		.byte 'F'
		.word fillMem
		.word fDesc
;
		.byte 'H'	;hex dump
		.word hexDump
		.word hDesc
;
		.byte 'J'	;jump to address
		.word jumpAddress
		.word jDesc
;
		.byte 'K'	;return to KIM monitor
		.word returnKim
		.word kDesc
;
		.byte 'L'	;load Intel HEX file
		.word loadHex
		.word lDesc
;
		.byte 'M'	;perform memory test
		.word memTest
		.word mDesc
;
		.byte 'O'	;branch offset calculator
		.word offCalc
		.word oDesc
;
		.byte 'Q'
		.word xKimCurrentBank
		.word qDesc
;
		.byte 'R'   ;switch to other ram bank
		.word xKimSwapBank
		.word rDesc
;
		.byte 'S'	;save to paper tape
		.word ptpSave
		.word sDesc
;
		.byte'T'  ;load from paper tape
		.word ptpLoad
		.word tDesc
;
		.byte 'V'
		.word doVersion
		.word vDesc
;
.if USE_WOZMON
		.byte 'W' ;start Wozmon
		.word doWozmon
		.word wDesc
.endif
;
		.byte 'Z' ; Fill memory region with 0
		.word fillMemZero
		.word zDesc
;
		.byte '!'	;do cold restart
		.word doCold
		.word bangDesc
;
		.byte 0	;marks end of table
;
;=====================================================
; Descriptions for each command in the command table.
; This wastes a lot of space... I'm open for any
; suggestions to keep the commands clear but reducing
; the amount of space this table consumes.
;
quesDesc:	.asciiz "? ........... Show this help"
aDesc:		.asciiz "A ........... ROM addresses"
bDesc:      .asciiz "B ........... Microsoft BASIC"
cDesc:		.asciiz "C ........... Clear display"
eDesc:		.asciiz "E xxxx ...... Edit memory"
fDesc:		.asciiz "F xxxx xxxx . Fill memory region with value"
hDesc:		.asciiz "H xxxx xxxx . Hex dump memory"
jDesc:		.asciiz "J xxxx ...... Jump to address"
kDesc:		.asciiz "K ........... Go to KIM monitor"
lDesc:		.asciiz "L ........... Load HEX file"
mDesc:		.asciiz "M xxxx xxxx . Memory test"
oDesc:		.asciiz "O xxxx xxxx . Calculate branch offset"
qDesc:		.asciiz "Q ........... Query active memory bank"
rDesc:		.asciiz "R ........... Switch to the other memory bank"
sDesc:		.asciiz "S xxxx xxxx . Save address range to paper tape"
tDesc:		.asciiz "T ........... Load from 'paper tape'"
vDesc:		.asciiz "V ........... Version"
.if USE_WOZMON
wDesc:		.asciiz "W ........... Go to Wozmon monitor"
.endif
zDesc:		.asciiz "Z xxxx xxxx . zero memory area"
bangDesc:	.asciiz "! ........... Do a cold start"
;
;=====================================================
; Return to KIM monitor.  Before returning, set the
; "open address" to the start of the extended monitor
; so the KIM monitor is pointing to it by default.
;
returnKim:
		jsr	putsil
		.byte CR,LF
		.byte "Returning to KIM..."
		.byte CR,LF,0
;		lda	#reentry&$0ff
;		sta	POINTL	;point back to start...
;		lda	#reentry/256
;		sta	POINTH	;...of this code
		jmp	SHOW1	;return to KIM

goBasic:
		lda #$01
		cmp isROMAtC000
		beq startBasic
		jsr putsil
		.byte CR,LF,"Microsoft BASIC is not in ROM; RAM at C000-DFFF",CR,LF,0
		rts

startBasic:
		jsr putsil
		.byte CR,LF,"Starting Microsoft BASIC",CR,LF,0
		jmp MSBASIC_START
;
;=====================================================
; Jump to Wozmon
;
.if USE_WOZMON
doWozmon:
		jsr putsil
		.byte CR,LF
		.byte "Starting Wozmon..."
		.byte CR,LF,0
		jmp WOZMON_START
.endif
;
;=====================================================
; Print interesting address
.import RESET
.import NMI
.import IRQ
doAddresses:
		jsr CRLF
		
		jsr putsil
		.asciiz "KIM-1 Monitor    : "
		lda #<START
		ldy #>START
		jsr praddrCRLF

		jsr putsil
		.asciiz "Microsoft BASIC  : "
		lda #$01
		cmp isROMAtC000
		bne noBasic
		lda #<MSBASIC_START
		ldy #>MSBASIC_START
		jsr praddrCRLF
		jmp nextAddr
noBasic:
		jsr putsil
		.asciiz "Basic ROM not mapped"
		jsr CRLF
nextAddr:

		jsr putsil
		.asciiz "Extended Monitor : "
		lda #<XKIM_MONITOR
		ldy #>XKIM_MONITOR
		jsr praddrCRLF

		jsr putsil
		.asciiz "Wozmon           : "
		lda #<WOZMON_START
		ldy #>WOZMON_START
		jsr praddrCRLF

		; Need to read the contents of NMI, RESET and IRQ.  Where the vectors point to is more interesting than where the 
		; labels are in RAM.  
		jsr putsil
		.asciiz "NMI vector       : "
		lda NMI
		ldy NMI+1
		jsr praddrCRLF
		
		jsr putsil
		.asciiz "Reset vector     : "
		lda RESET
		ldy RESET+1
		jsr praddrCRLF

		jsr putsil
		.asciiz "IRQ vector       : "
		lda IRQ
		ldy IRQ+1
		jsr praddrCRLF

		rts
praddrCRLF:
		sta POINTL
		sty POINTH
		lda #'$'
		jsr OUTCH
		jsr PRTPNT
		jmp CRLF				; Will rts for us
;=====================================================
; Clear the terminal using VT100 control codes
clearTerm:	
		jsr putsil
		.byte $1b,$5b,$32,$4a,$1b,$5b,$48,CR,LF,0
		rts

doClearTerm:
		jmp clearTerm
;
;=====================================================
; Force a cold start.
doCold:
		inc	ColdFlag	;foul up flag
		jmp	extKim		;...and restart
;
;=====================================================
; Command handler for the ? command
;
showHelp:
		jsr	putsil
		.byte CR,LF
		.byte "Available commands:"
		.byte CR,LF,LF,0
;
; Print help for built-in commands...
;
		lda	#.lobyte(commandTable)
		sta	POINTL
		lda	#.hibyte(commandTable)
		sta	POINTH
		jsr	displayHelp	;display help
;
; Now print help for the extension commands...
;
;		lda	ExtensionAddr
;		sta	POINTL
;		lda	ExtensionAddr+1
;		sta	POINTH
;		jsr	displayHelp
		jsr	CRLF
		rts
;
;=====================================================
; This is a generic "not done yet" holder.  Any
; unimplemented commands should point here.
;
NDY:
		jsr	putsil
		.byte CR,LF
		.byte "Sorry, not done yet."
		.byte CR,LF,0
		rts
; 
;=====================================================
; Do a hex dump of a region of memory.  This code was
; taken from MICRO issue 5, from an article by
; J.C. Williams.  I changed it a bit, but it's still
; basically the same code.
;
; Slight bug: the starting address is rounded down to
; a multiple of 16.  I'll fix it eventually.
;
hexDump:
		jsr	getAddrRange
		bcs	cmdRet2
		jsr	CRLF
		jsr	doHexDump	;subroutine does it
cmdRet2:
		rts
;
;=====================================================
; This subroutine does a hex dump from the address in
; SAL/H to EAL/H.
;
; Move start address to POINT but rounded down to the
; 16 byte boundary.
;
doHexDump:
		lda	SAH
		sta	POINTH
		lda	SAL
		and	#$f0	;force to 16 byte
		sta	POINTL
;
; This starts each line.  Set flag to indcate we're
; doing the hex portion, print address, etc.
;
hexdump1:
		lda	#0	;set flag to hex mode
		sta	ID
		jsr	CRLF
		jsr	PRTPNT	;print the address
hexdump2:
		lda	POINTL	;push start of line...
		pha		;...address onto stack
		lda	POINTH
		pha
		jsr	space2
		ldx	#BYTESLINE-1	;number of bytes per line
		jsr	space2	;space before data

hexdump3:
		ldy	#0	;get next byte...
		lda	(POINTL),y
		bit	ID	;hex or ASCII mode?
		bpl	hexptbt	;branch if hex mode
;
; Print char if printable, else print a dot
;
		cmp	#' '
		bcc	hexdot
		cmp	#'~'
		bcc	hexpr
hexdot:
		lda	#DOT
hexpr:
		jsr	OUTCH
		jmp	hexend
;
; Print character as hex.  
;
hexptbt:
	 	jsr	PRTBYT	;print as hex
		jsr	space	;and follow with a space
;
; See if we just dumped the last address.  If not, then
; increment to the next address and continue.
;
hexend:
	  	lda	POINTL	;compare first
		cmp	EAL
		lda	POINTH
		sbc	EAH
;
; Now increment to the next address
;
		php
		jsr	INCPT
		plp
		bcc	hexlntst
;
		bit	ID
		bmi	hexdone
		dex
		bmi	hexdomap
hexdump5:
		jsr	space3
		dex
		bpl	hexdump5
hexdomap:
		dec	ID
		pla
		sta	POINTH
		pla
		sta	POINTL
		jmp     hexdump2
hexlntst:
		dex
		bpl	hexdump3
		bit	ID
		bpl	hexdomap
		pla
		pla
		jmp	hexdump1
;
; Clean up the stack and we're done
;
hexdone:
		jsr	CRLF
		pla
		pla
		rts
;
;=====================================================
; This does a memory test of a region of memory.  One
; problem with the KIM is that there is no routine to
; see if a new character is starting, so this loop
; just runs forever unless the user presses RESET.
;
; Asks for the starting and ending locations.
;
; This cycles a rolling bit, then adds a ninth
; pattern to help detect shorted address bits.
; Ie: 01, 02, 04, 08, 10, 20, 40, 80, BA
;
pattern		= 	CHKL		;re-use some KIM locations
original	= 	CHKH
;
; Test patterns
;
PATTERN_0	= 	$01
PATTERN_9	= 	$ba
;
cmdRet5:
		rts
memTest:
		jsr	getAddrRange	;get range
		bcs	cmdRet5		;branch if abort
;
		jsr	putsil
		.byte CR,LF
		.asciiz "Testing memory.  Press RESET to abort"
		lda	#PATTERN_0	;only set initial...
		sta	pattern		;..pattern once
;
; Start of loop.  This fills/tests one complete pass
; of memory.
;
memTestMain:
		lda	SAL	;reset pointer to start
		sta	POINTL
		lda	SAH
		sta	POINTH
;
; Fill memory with the rolling pattern until the last
; location is filled.
;
		ldy	#0
		lda	pattern
		sta	original
memTestFill:
		sta	(POINTL),y
		cmp	#PATTERN_9	;at last pattern?
		bne	memFill3
		lda	#PATTERN_0	;restart pattern
		jmp	memFill4
;
; Rotate pattern left one bit
;
memFill3:
		asl	a
		bcc	memFill4	;branch if not overflow
		lda	#PATTERN_9	;ninth pattern
;
; The new pattern is in A.  Now see if we've reached
; the end of the area to be tested.
;
memFill4:
		pha			;save pattern
		lda	POINTL
		cmp	EAL
		bne	memFill5
		lda	POINTH
		cmp	EAH
		beq	memCheck
;
; Not done, so move to next address and keep going.
;
memFill5:
		jsr	INCPT
		pla			;recover pattern
		jmp	memTestFill
;
; Okay, memory is filled, so now go back and test it.
; We kept a backup copy of the initial pattern to
; use, but save the current pattern as the starting
; point for the next pass.
;
memCheck:
		pla
		sta	pattern		;for next pass
		lda	SAL		;reset pointer to start
		sta	POINTL
		lda	SAH
		sta	POINTH
		lda	original	;restore initial pattern
		ldy	#0
memTest2:
		cmp	(POINTL),y
		bne	memFail
		cmp	#PATTERN_9
		bne	memTest3
;
; Time to reload the pattern
;
		lda	#PATTERN_0
		bne	memTest4
;
; Rotate pattern left one bit
;
memTest3:
		asl	a
		bcc	memTest4
		lda	#PATTERN_9
;
; The new pattern is in A.
;
memTest4:
		pha			;save pattern
		lda	POINTL
		cmp	EAL
		bne	memTest5	;not at end
		lda	POINTH
		cmp	EAH
		beq	memDone		;at end of pass
;
; Not at end yet, so inc pointer and continue
;
memTest5:
		jsr	INCPT
		pla
		jmp	memTest2
;
; Another pass has completed.
;
memDone:
		pla
		lda	#DOT
		jsr	OUTCH
		jmp	memTestMain
;
; Failure.  Display the failed address, the expected
; value and what was actually there.
;
memFail:
		pha		;save pattern for error report
		jsr	putsil
		.byte CR,LF
		.asciiz "Failure at address "
		jsr	PRTPNT
		jsr	putsil
		.asciiz ".  Expected "
		pla
		jsr	PRTBYT
		jsr	putsil
		.asciiz " but got "
		ldy	#0
		lda	(POINTL),y
		jsr	PRTBYT
		jsr	CRLF
cmdRet4:
		rts
;
;=====================================================
; Edit memory.  This waits for a starting address to be
; entered.  It will display the current address and its
; contents.  Possible user inputs and actions:
;
;   Two hex digits will place that value in memory
;   RETURN moves to next address
;   BACKSPACE moves back one address
;
editMemory:
	    jsr	space
		jsr	getStartAddr
		bcs	cmdRet4
		lda	SAL		;move address into...
		sta	POINTL		;...POINT
		lda	SAH
		sta	POINTH
		jsr	CRLF
		jsr	doEdit
		rts
;
;=====================================================
; This subroutine edits memory.  On entry, POINT has
; the first address to edit.  Upon exit, POINT will
; have been updated to next address to edit.
;
; Display the current location
;
doEdit:
		jsr	PRTPNT		;print address
		jsr	space
		ldy	#0
		lda	(POINTL),y	;get byte
		jsr	PRTBYT		;print it
		jsr	space
;
		jsr	getHex
		bcs	editMem2	;not hex
editMem7:
		ldy	#0
		sta	(POINTL),y	;save new value
;
; Bump POINT to next location
;
editMem3:
		jsr	CRLF
		jsr	INCPT
		jmp	doEdit
;
; Not hex, so see if another command.  Valid commands are:
;
;    CR = advance to next memory location
;    BS = move to previous location
;    R  = compute relative offset
;
editMem2:
		cmp	#'R'		;compute relative branch
		beq	editMem4
		cmp	#CR
		beq	editMem3	;move to next
		cmp	#BS
		bne     editexit		;else exit
;
; Move back one location
;
		lda	POINTL
		bne	editMem8
		dec	POINTH
editMem8:
		dec	POINTL
		jsr	CRLF
		jmp	doEdit
;
editexit:
		rts
;
; They want to calculate a relative offset
;
editMem4:
		jsr	putsil
		.asciiz "elative offset to: "
		jsr	getEndAddr
		bcs	doEdit		;bad input
;
; Need to load POINTL/POINTH into SAL/SAH and then
; decrement by one.
;
		lda	POINTH
		sta	SAH
		lda	POINTL
		sta	SAL
		bne	editMem5
		dec	SAH
editMem5:
		dec	SAL
;
		jsr	ComputeOffset
		bcc	editMem6	;value good
		jsr	putsil
		.asciiz " - out of range"
		jmp	doEdit
;
; Relative offset is in A.
;
editMem6:
		pha
		jsr	space
		pla
		pha
		jsr	PRTBYT		;print it
		pla
		jmp	editMem7	;store it
;
;=====================================================
; This handles the Load hex command.
;
loadHex:		
		jsr	putsil
		.byte CR,LF,0
		jsr	loadHexConsole	;load from console
		jmp	loadCheckAuto	;check auto-run
;
; If the auto-run vector is no longer $ffff, then jump
; to whatever it points to.
;
loadCheckAuto:
		lda	AutoRun+1
		cmp	#$ff		;unchanged?
		beq	lExit11
		jmp	(AutoRun)	;execute!
lExit11:
		rts
;
;=====================================================
; This subroutine is called to load a hex file from
; the console.
;
loadHexConsole:
		lda	#$ff
		sta	AutoRun+1
		jsr	putsil
		.byte CR,LF
		.byte "Waiting for file, or ESC to exit..."
		.byte CR,LF,0
;
; The start of a line.  First character should be a
; colon, but toss out CRs, LFs, etc.  Anything else
; causes an abort.
;
loadStart:
		jsr	xkimGetCH	;get start of line
		cmp	#CR
		beq	loadStart
		cmp	#LF
		beq	loadStart
		cmp	#COLN		;what we expect
		bne	loadAbortB
;
; Get the header of the record
;
		lda	#0
		sta	CHKL		;initialize checksum
;
		jsr	getHex		;get byte count
		bcs	loadAbortC
		sta	byteCount	;save byte count
		jsr	updateCrc
		jsr	getHex		;get the MSB of offset
		bcs	loadAbortD
		sta	POINTH
		jsr	updateCrc
		jsr	getHex		;get LSB of offset
		bcs	loadAbortE
		sta	POINTL
		jsr	updateCrc
		jsr	getHex		;get the record type
		bcs	loadAbortF
		jsr	updateCrc
;
; Only handle two record types:
;    00 = data record
;    01 = end of file record
;
		cmp	#DATA_RECORD
		beq	loadDataRec
		cmp	#EOF_RECORD
		beq	loadEof
;
; Unknown record type
;
		lda	#'A'		;reason
;
; This is the common error handler for various reasons.
; On entry A contains an ASCII character which is output
; to indicate the specific error reason.
;
loadAbort:
	    pha			;save reason
		jsr	putsil
		.byte CR,LF
		.byte "Aborting, reason: "
		.byte 0
		pla			;restore and...
		jsr	OUTCH		;...display reason
		jsr	CRLF
loadExit:
		rts
;
; Various error reason codes.  This was meant to be
; very temporary as I worked out the real problem, but
; this debug code immediately "solved" the problem so
; I just left these as-is until the root cause is
; discovered.
;
loadAbortB:	lda	#'B'
		bne	loadAbort
;
loadAbortC:	lda	#'C'
		bne	loadAbort
;
loadAbortD:	lda	#'D'
		bne	loadAbort
;
loadAbortE:	lda	#'E'
		bne	loadAbort
;
loadAbortF:	lda	#'F'
		bne	loadAbort
;
loadAbortG:	lda	#'G'
		bne	loadAbort
;
loadAbortH:	lda	#'H'
		bne	loadAbort
;
; EOF is easy
;
loadEof:
		jsr	getHex		;get checksum
		jsr	putsil
		.byte CR,LF
		.byte "Success!"
		.byte CR,LF,0
		rts
;
; Data records have more work.  After processing the
; line, print a dot to indicate progress.  This should
; be re-thought as it could slow down loading a really
; big file if the console speed is slow.
;
loadDataRec:
		ldx	byteCount	;byte count
		ldy	#0		;offset
loadData1:
		stx	byteCount
		sty	saveY
		jsr	getHex
		bcs	loadAbortG
		jsr	updateCrc
		ldy	saveY
		ldx	byteCount
		sta	(POINTL),y
		iny
		dex
		bne	loadData1
;
; All the bytes were read so get the checksum and see
; if it agrees.  The checksum is a twos-complement, so
; just add the checksum into what we've been calculating
; and if the result is zero then the record is good.
;
		jsr	getHex		;get checksum
		clc
		adc	CHKL
		bne	loadAbortH	;non-zero is error
		jmp	loadStart
; Go back to the monitor
lExit1:	
		rts
;

;=====================================================
; Adds the character in A to the CRC.  Preserves A.
;
updateCrc:
		pha
		clc
		adc	CHKL
		sta	CHKL
		pla
		rts
;
;=====================================================
; Handles the command to prompt for an address and then
; jump to it.
;
jumpAddress:
	    jsr	space
		jsr	getStartAddr
		bcs	cmdRet	;branch on bad address
		jsr	CRLF
		jmp	(SAL)	;else jump to address
;
cmdRet:
		rts
;
;=====================================================
; Calculate the offset for a relative branch.  6502
; relative branch calculations are well known.
;
; Offset from branch (BASE) = TARGET - (BASE+2).
; If the result is positive, upper byte must be
; zero.  If negative, upper byte must be FF.
;
; BASE	TARGET	Computed	Actual
; 0200	0200	0200-(0200+2)	FFFE
; 0200	020E	020E-(0200+2)	000C
; 0226	0220	0220-(0226+2)	FFF8
; 0156	015A	015A-(0156+2)	0002
; 015C	012D	012D-(015C+2)	FFCF
; 0200	0300	0300-(0200+2)	00FE - out of range
; 0300	0200	0200-(0300+2)	FEFE - out of range
;
offCalc:
		jsr	putsil
		.asciiz " - Branch instruction address: "
		jsr	getStartAddr
		bcs	calcExit
		jsr	putsil
		.asciiz ", branch to: "
		jsr	getEndAddr
		bcs	calcExit
		jsr	ComputeOffset	;does the work
		bcc	relgood			;if good offset
;
; Branch is out of range.
;
		jsr	putsil
		.byte " - out of range",CR,LF
calcExit:
		rts
;
; Branch is in range so dislay the value.
;
relgood:
		pha			;save offset
		jsr	putsil
		.asciiz " Offset: "
		pla
		jsr	PRTBYT
		rts
;
;=====================================================
; Use the PAD direction port to toggle which memory 
; bank is currently in use.  
; TODO: explain PAD behavior 
xKimSwapBank:
		jsr putsil 
		.byte CR,LF
		.byte "Swapping memory bank",CR,LF
		.byte "Current Bank: "
		.byte 0
		lda BANK_PORT
		and #BANK_MASK
		jsr PRTBYT

		jsr swapBank
		
		jsr putsil 
		.byte CR,LF
		.byte "New Bank    : "
		.byte 0
		lda BANK_PORT
		and #BANK_MASK
		jsr PRTBYT
		jsr CRLF
		rts
;
;=====================================================
xKimCurrentBank:
		jsr putsil 
		.byte CR,LF
		.byte "Current Memory Bank: ",0
		lda BANK_PORT
		jsr PRTBYT
		jsr CRLF
		rts
;=====================================================
; Fill a region of memory with a Zero
fillMemZero:
		jsr	getAddrRange
		bcs	fillMemExit
		jsr CRLF
		lda #$0
		jsr	doFillMem
		jmp fillMemDone
;=====================================================
; Fill a region with a user provided value
fillMem:
		jsr getAddrRange
		bcs fillMemExit
		jsr CRLF
		jsr putsil
		.asciiz "Hex value: "
		jsr getHex
		jsr putsil
		.byte CR,LF,"Filling ... ",0
		jsr doFillMem
fillMemDone:
		jsr putsil
		.byte "Done",CR,LF,0
fillMemExit:
		rts
;=====================================================
; Fill a memory region with value in A.  Clobbers A, X & Y
doFillMem:
		tax
		lda	SAH
		sta	POINTH
		lda	SAL
		sta	POINTL
		ldy #$0
fillMemLoop:
		txa
		sta (POINTL),Y

		; Are we finished?  Check POINT against EA
		lda	POINTL		;compare low byte of address first
		cmp	EAL
		lda	POINTH
		sbc	EAH			; Carry will be clear if we're finished looping
		jsr INCPT		; otherwise increment POINT and loop
		bcc fillMemLoop

		rts
;
;=====================================================
; Show version info
doVersion:
		jsr CRLF
		jsr shortVersion
		jsr CRLF
		jsr longVersion
		rts
;
;=====================================================
;
; Add new commands here...
;
;
;=====================================================
;=====================================================
; Utility functions below this line
;=====================================================
;=====================================================
;
; This subroutine will search for a command in a table
; and call the appropriate handler.  See the command
; table near the start of the code for what the format
; is.  If a match is found, jump to the code.  Else, return.
; Use carry flag to indicate not found
;
searchCmd:
		clc
		ldy	#0
cmdLoop:
		lda	(POINTL),y
		beq	cmdNotFound
		cmp	ACC	;compare to user's input
		beq	cmdMatch
		iny		;start of function ptr
		iny
		iny		;start of help
		iny
		iny		;move to next command
		bne	cmdLoop
;
; It's found!  Load up the address of the code to call,
; pop the return address off the stack and jump to the
; handler.
;
cmdMatch:
		iny
		lda	(POINTL),y	;handler LSB
		pha
		iny
		lda	(POINTL),y	;handler MSB
		sta	POINTH
		pla
		sta	POINTL
		jmp	(POINTL)
;
; Not found, so set carry flag and return.
;
cmdNotFound:
		sec
		rts
;
;=====================================================
; Given a pointer to a command table in POINT, display
; the help text for all commands in the table.
;
displayHelp:
		ldy	#0	;index into command table
showHelpLoop:
		lda	(POINTL),y	;get command
		beq	showHelpDone	;jump if at end
;
; Display this entry's descriptive text
;
		iny		;skip over command
		iny		;skip over function ptr
		iny
		lda	(POINTL),y
		sta	INL
		iny
		lda	(POINTL),y
		sta	INH
		tya
		pha
		jsr	_OUTSP
		jsr	_OUTSP
		jsr	puts	;print description
		jsr	CRLF
		pla
		tay
		iny		;point to next entry
		bne	showHelpLoop
showHelpDone:
		rts
;
;=====================================================
; Print some spaces.
;
space3:		jsr	space
space2:		jsr	space
space:   	jmp	_OUTSP
;
;=====================================================
; This prints the null-terminated string that
; immediately follows the JSR to this function.  This
; version was written by Ross Archer and is at:
;
;    www.6502.org/source/io/primm.htm
;
putsil:
		sta saveA
		txa 
		sta saveX
		tya 
		sta saveY
		pla
		sta	INL
		pla
		sta	INH
		ldy	#1
		jsr	putsy
		inc	INL
		bne	puts2
		inc	INH
puts2:
		jmp	(INL)
;
;=====================================================
; This prints the null terminated string pointed to by
; INL and INH.  Modifies those locations to point to
; the end of the string.
;
puts:
		ldy	#0
putsy:
		lda	(INL),y
		inc	INL
		bne	puts1
		inc	INH
puts1:
		ora	#0
		beq	putsdone
		sty	saveY
		jsr	OUTCH	;print character
		ldy	saveY
		jmp	putsy
putsdone:
		lda saveY
		tay
		lda saveX
		tax
		lda saveA	
		rts
;
;=====================================================
; This gets two hex characters and returns the value
; in A with carry clear.  If a non-hex digit is
; entered, then A contans the offending character and
; carry is set.
;
getHex:
		jsr	getNibble
		bcs	getNibBad
		asl	a
		asl	a
		asl	a
		asl	a
		sta	saveA
		jsr	getNibble
		bcs	getNibBad
		ora	saveA
		clc
		rts
;
; Helper.  Gets next input char and converts to a
; value from 0-F in A and returns C clear.  If not a
; valid hex character, return C set.
;
getNibble:
		jsr	xkimGetCH
		ldx	#nibbleHexEnd-nibbleHex-1
getNibble1:
		cmp	nibbleHex,x
		beq	getNibF	;got match
		dex
		bpl	getNibble1
getNibBad:
		sec
		rts

getNibF:
		txa		;index is value
		clc
		rts
;
nibbleHex:	.byte "0123456789ABCDEF"
nibbleHexEnd	= 	*
;
;=====================================================
; Gets a four digit hex address amd places it in
; SAL and SAH.  Returns C clear if all is well, or C
; set on error and A contains the character.
;
getStartAddr:
		jsr	getHex
		bcs	getDone
		sta	SAH
		jsr	getHex
		bcs	getDone
		sta	SAL
		clc
getDone:
		rts
;
;=====================================================
; Gets a four digit hex address amd places it in
; EAL and EAH.  Returns C clear if all is well, or C
; set on error and A contains the character.
;
getEndAddr:
		jsr	getHex
		bcs	getDone
		sta	EAH
		jsr	getHex
		bcs	getDone
		sta	EAL
		clc
		rts
;
;=====================================================
; Get an address range and leave them in SAL and EAL.
;
getAddrRange:
	    jsr	space
		jsr	getStartAddr
		bcs	getDone
		lda	#'-'
		jsr	OUTCH
		jsr	getEndAddr
		rts
;
;=====================================================
; This computes the relative offset between the
; address in SAL/SAH (address of branch instruction)
; and EAL/EAH (address to jump to).  If a valid range,
; returns C clear and the offset in A.  If the branch
; is out of range, C is set and A undefined.  Modifies
; A, SAL and SAH.
;
ComputeOffset:
;
; Add two to the end (BASE) address.  For calculations:
;   BASE = SAL/SAH
;   TARGET = EAL/EAH
;
		clc
		lda	SAL
		adc	#2
		sta	SAL
		bcc	coffsub
		inc	SAH
;
; Subtract the BASE (end) address from the TARGET (start)
;
coffsub:
		sec
		lda	EAL
		sbc	SAL
		pha		;save for later
		sta	SAL
		lda	EAH
		sbc	SAH
		sta	SAH	;SAL/SAH contain offset
;
; High part must be either FF for negative branch or
; 00 for a positive branch.  Cheat a bit here by rolling
; the MSBit into C and adding to the MSByte.  If the
; result is zero then everything is cool.
;
		pla		;restore LSB of offset
		pha
		asl	a	;put sign into C
		lda	SAH
		adc	#0
		beq	cogood	;branch if in range
;
		pla		;clean up stack
		sec		;error
		rts
;
cogood:
		pla		;get back offset
		clc
		rts
;
;=====================================================
; Print character in A as two hex digits to the
; current output device (console or file).
;
HexToOutput:
		pha		;save return value
		pha
		lsr	a	;move top nibble to bottom
		lsr	a
		lsr	a
		lsr	a
		jsr	hexta	;output nibble
		pla
		jsr	hexta
		pla		;restore
		rts
;
hexta:	and	#%0001111
		cmp	#$0a
		clc
		bmi	hexta1
		adc	#7
hexta1:	adc	#'0'	;then fall into...
		jmp OUTCH
;
;========================================================
; Given a binary value in A, display it as two decimal
; digits.  The input can't be greater than 99.  Always
; print a leading zero if less than 10.
;
DecToPutout:
		ldy	#0		;counts 10s
out1:	cmp	#10
		bcc	out2	;below 10
		iny			;count 10
		sec
		sbc	#10
		jmp	out1
;
out2:	pha			;save ones
		tya			;get tens
		jsr	out3	;print tens digit
		pla			;restore ones
;
out3:	ora	#'0'
		jsr	OUTCH
		rts
;
;=====================================================
; Swap the active memory bank (0->1 or 1->0)
swapBank:
		lda BANK_PORT
		eor #BANK_PIN
		jsr PRTBYT
		; fallthrough
setBank:
		sta BANK_PORT
		rts
;
;=====================================================
; initialize memory banking
initBank:
		lda #$0
		jmp setBank
;
;=====================================================
; Use the Wozmon GETKEY, which does not echo, to get 
; user TTY input.  Optionally blindly upcase the input.
xkimGetCH:
		jsr GETKEY		; Call the Wozmon GETKEY (no echo)
.if UPCASE_COMMANDS
		cmp #'a'
		bcc notLowerCase
		cmp #'z'+1
		bcs notLowerCase
		sec
		sbc #$20
notLowerCase:
.endif
		jsr ECHO
		rts
;
;=====================================================
; Reimplemention of KIM-1 "Load from paper tape"
;
.include "ptpload.s"
;
;=====================================================
; Version version
shortVersion:
		jsr putsil 
		.byte "KIM-1 64K RAM, 16K ROM Card Monitor, rev "
		.byte XVERSION+'0','.',XREVISION+'0',' '
		.byte CR,LF
		.byte 0
		jsr tellROM
		rts
;
longVersion:
		jsr putsil 
		.byte "Based on the Extended KIM Monitor v"
		.byte VERSION+'0','.',REVISION+'0',' '
	.if	BETA_VER
		.byte "BETA "
		.byte BETA_VER+'0'
		.byte ' '
	.endif
		.byte "by Corsham Technologies, LLC"
		.byte CR,LF
		.byte "www.corshamtech.com"
		.byte CR,LF
		.byte 0
		rts
;
;=====================================================
; Tell user if ROM is at C000
tellROM:
		lda #$01
		cmp isROMAtC000
		bne itsRAM
		jsr putsil 
		.byte "ROM",0
		jmp tellExit
itsRAM:
		jsr putsil
		.byte "RAM",0

tellExit:
		jsr putsil 
		.byte " mapped at C000-DFFF",CR,LF,0
		rts
;
;=====================================================
; Check if ROM is mapped at C000
checkForROM:
		lda #$01		; Assume ROM is mapped at C000
		sta isROMAtC000

		lda $C000		; Load from C000
		sta saveA		; save it for later
		eor #$FF		; Modify the value
		sta $C000		; and write it back to C000

		lda $C000		; re-read C000
		cmp saveA		; and compare against original value
		bne isRAM       ; If not equal, it's RAM
		rts

isRAM:
		lda saveA		; It's RAM, restore the original value
		sta $C000
		lda #$00        ; Set variable to indicate it's RAM
		sta isROMAtC000
		rts
	
