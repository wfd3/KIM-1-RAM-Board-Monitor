;=====================================================
; Useful constants
false = 0
true  = 1
;
;=====================================================
; Imports from linker
.import __XKIM_LOAD__
.import __WOZMON_LOAD__
.import __INIT_LOAD__
.import __KEYWORDS_LOAD__
.import __TRAMP_LOAD__
; 
;=====================================================
;
; Translate load address variables from the linker into more readable
; labels
XKIM_START      = __XKIM_LOAD__
WOZMON_START    = __WOZMON_LOAD__
MSBASIC_START   = __INIT_LOAD__
TRAMPOLINE      = __TRAMP_LOAD__
BASIC_KEYWORDS  = __KEYWORDS_LOAD__
; 
; And add a label for the KIM-1 monitor start
KIM1_START      = SHOW1         ; KIM-1 Monitor
;
;=====================================================
; Build Options
;
USE_WOZMON      = true          ; Include Wozmon in the ROM
;
UPCASE_COMMANDS = true          ; Automatically uppercase command input
;
;=====================================================
; Program info
;
; Extended Version number
XVERSION        = 0
XREVISION       = 6
;
; Original Corsham version number
;
VERSION	        = 1
REVISION        = 8
BETA_VER        = 0
;
;=====================================================
; Common non-printable ASCII constants
;
NUL		    = $00
BS		    = $08
LF		    = $0a
FF          = $0C                   ; Formfeed character; clears the terminal
CR		    = $0d
ESC		    = $1b
SPC		    = $20
DOT		    = '.'					; Period
COLN	    = ':'					; Colon  
BACKSL	    = $5c                   ; Backslash (ca65 apparently doesn't handle '\' correctly)
DEL         = $7F
;
;=====================================================
; KIM-1 ROM addresses
;
; KIM Zeropage variables
PCL         =  	$ef
PCH 		= 	$f0
PREG 		= 	$f1
SPUSER 		= 	$f2
ACC 		= 	$f3
YREG 		= 	$f4
XREG 		= 	$f5
CHKHI 		= 	$f6 
CHKSUM 		= 	$f7
INL 		= 	$f8
INH 		= 	$f9
POINTL 		= 	$fa
POINTH 		= 	$fb
TEMP 		= 	$fc
TMPX 		= 	$fd
CHAR 		= 	$fe
MODE 		= 	$ff
;
; KIM I/O locations
SAD			= 	$1740
SBD         =   $1742
;
; RIOT data ports
PAD         =   $1700       ;Data port A
PADD		= 	$1701
PDB         =   $1702
PBDD        =   $1703
; 
; KIM-1 data locations (page 39)
CHKL        =   $17E7
CHKH        =   $17E8       ;CHKSUM
SAVX        =   $17E9       ;(3-BYTES)
VEB         =   $17EC       ;VOLATILE EXEC BLOCK (6-B)
CNTL30      =   $17F2       ;TTY DELAY
CNTH30      =   $17F3       ;TTY DELAY
TIMH        =   $17F4	    ;
SAL         =   $17F5       ;LOW STARTING ADDRESS
SAH         =   $17F6       ;HI STARTING ADDRESS
EAL         =   $17F7       ;LOW ENDING ADDRESS
EAH         =   $17F8       ;HI ENDING ADDRESS
ID          =   $17F9       ;TAPE PROGRAM ID NUMBER
;
; KIM subroutines located in the ROMs
NMIT		= 	$1c1c	    ;NMI handler
IRQT		= 	$1c1f	    ;IRQ handler
RST	    	= 	$1c22	    ;RESET handler
TTYKB		= 	$1c77	    ;do keyboard monitor
CRLF		= 	$1e2f	    ;print CR/LF
PRTPNT		= 	$1e1e	    ;print POINT
PRTBYT		= 	$1e3b	    ;print A as two hex digits
GETCH		= 	$1e5a	    ;get a key from tty into A
_OUTSP		= 	$1e9e	    ;print a space
OUTCH		= 	$1ea0	    ;print A to TTY
SHOW		= 	$1dac
SHOW1		= 	$1daf
INCPT		= 	$1f63	    ;inc POINTL/POINTH
INITS 		=   $1e88
INIT1		= 	$1e8c
START		= 	$1c4f
CHK			= 	$1f91
_GETBYT		= 	$1f9d
PRTST		= 	$1e31
PACK		= 	$1fac
