.segment "EXTRA"
POINTL = $FA
POINTH = $FB
EAL = $17F7
EAH = $17F8

.import ptpLoad
.import ptpDump

; ----------------------------------------------------------------------------
; SYS - Jump to an address
; ----------------------------------------------------------------------------
SYS:
        jsr     FRMNUM
        jsr     GETADR
       
        ; Emulate an indirect JSR
        lda     #>SYS_RETADR
        pha
        lda     #<SYS_RETADR
        pha
        jmp     (LINNUM)

SYS_RETADR = *-1
        rts

; --------------------------------------------------------------------------
; CLS - Clear terminal with a form feed 
FORMFEED      := $0C
CLS:
        lda     #FORMFEED
        jmp     MONCOUT         ; will rts for us

; ---------------------------------------------------------------------------
; GET_UPPER - Support case insensitive keywords.  Copied from the KBD port
GET_UPPER:
        lda     INPUTBUFFERX,x
LF430:                  ; called from chrget.s
        cmp     #'a'
        bcc     notAscii
        cmp     #'z'+1
        bcs     notAscii
        sbc     #$1F
notAscii:
        rts

; ---------------------------------------------------------------------------
; CHKDEL - Make DEL work like BS
;
; Because the KIM-1 uses DEL/RUBOUT to determine TTY baud rate, the user 
; TTY needst to be reconfigured to send DEL rather than BS.  This converts a 
; DEL into a BS and writes the BS back to the TTY to have the same behavior as 
; if a BS was received in the first place.
DEL     := $7F
BS      := $08
CHKDEL:
        cmp     #DEL
        bne     CHKDELX
        lda     #BS
        jsr     MONCOUT         ; Clobbers A
        lda     #BS
CHKDELX:
        rts
; ---------------------------------------------------------------------------
; PSAVE - Save program to paper tape
PSAVE:
        ; save the stack
        tsx
        stx     INPUTFLG
        ; Clobber it (why?)
        lda     #$37
        sta     $F2                     ;KIM-1 zeropage SP variable     

        ; set start in POINTL/H
        lda     TXTTAB
        ldy     TXTTAB+1
        sta     POINTL
        sty     POINTH
        
        ; set end in EAL/EAH
        lda     VARTAB
        ldy     VARTAB+1
        sta     EAL
        sty     EAH

        ; Call dump to paper tape in KIM ROM
        jsr     ptpDump

        ; Restore SP
        ldx     INPUTFLG
        txs

        ; Print that we're done
        lda     #<QT_SAVED
        ldy     #>QT_SAVED
        jsr     STROUT
        rts

; ---------------------------------------------------------------------------
; PLOAD - Load program from paper tape
PLOAD:
        lda     TXTTAB
        ldy     TXTTAB+1
        sta     POINTL
        sty     POINTH
        lda     #<PLOAD_RESTART
        ldy     #>PLOAD_RESTART
        sta     GORESTART+1
        sty     GORESTART+2

        jsr     ptpLoad
        
PLOAD_RESTART:
        ldx     #$FF                    ; Reset the stack
        txs

        lda     #<RESTART               ; Reset RESTART
        ldy     #>RESTART
        sta     GORESTART+1
        sty     GORESTART+2

        bcc     PLOAD_OK                ; ptpLoad will return w/ Carry set if error
        
        ; Handle load error
        clc                             ; Clear carry flag
        lda     #$00                    ; NEW will immediately rts if Zero Flag clear, so set it
        jsr     NEW                     ; Clear any partial load
        ldx     #ERR_BADDATA            ; Set error message
        jmp     ERROR                   

PLOAD_OK:
        clc        
        lda     #<QT_LOADED
        ldy     #>QT_LOADED
        jsr     STROUT

        ldx     EAL
        ldy     EAH
        stx     VARTAB
        sty     VARTAB+1
        jmp     FIX_LINKS

QT_LOADED:
        .byte   "LOADED",CR,LF,0
QT_SAVED:
        .byte   CR,LF,"SAVED",CR,LF,0
