; configuration
CONFIG_11A := 1
; v2C works equally well, except the version string is incorrect
;CONFIG_2C := 1

CONFIG_MONCOUT_DESTROYS_Y := 1
CONFIG_NULL := 1
CONFIG_ROR_WORKAROUND := 1
CONFIG_SAFE_NAMENOTFOUND := 1
CONFIG_SCRTCH_ORDER := 2
CONFIG_PEEK_SAVE_LINNUM := 1  ; All the other rom based versions do this
CONFIG_BS_PATCH := 1

; zero page - same as KIM-1 ram version
ZP_START1 = $00
ZP_START2 = $15
ZP_START3 = $0A
ZP_START4 = $63

; constants
STACK_TOP := $FC
SPACE_FOR_GOSUB := $36
NULL_MAX := $F2 ; probably different in original version; the image I have seems to be modified; see PDF
WIDTH := 72
WIDTH2 := 56

; magic memory locations
L1800 := $1800    ; KIM-1 DUMPT (dump to tape)
L1873 := $1873    ; KIM-1 LOADT (load from tape)

; monitor functions
MONRDKEY := $1E5A ; KIM-1 GETCH
MONCOUT := $1EA0  ; KIM-1 OUTCH
;SYSTEM := $1DAF   ; KIM-1 SHOW1 (return to KIM-1 monitor)
.import XKIM_MONITOR
SYSTEM := XKIM_MONITOR   ; xKIM monitor

RAMSTART2 := $2000    ; Where RAM starts on my system; change to suit yours