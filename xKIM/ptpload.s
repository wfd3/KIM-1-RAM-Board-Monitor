
;       ** LOAD PAPER TAPE FROM TTY **

ptpLoadxKIM:
    jsr     ptpLoad
    jsr     putsil
    .byte   CR,LF,0
    rts

.export ptpLoad
ptpLoad:   
            jsr   putsil
            .byte    CR,LF,"Start paper tape",CR,LF,0
ptpL0:
            jsr   GETCH         ; LOOK FOR FIRST CHAR
            cmp   #';'          ; #$3B          ;SEMICOLON
            bne   ptpL0
            lda   #$00
            sta   CHKSUM
            sta   CHKHI
            jsr   GETBYT        ;GET BYTE COUNT
            tax                 ;SAVE IN X INDEX
            jsr   CHK           ;COMPUTE CHECKSUM
            jsr   GETBYT        ;GET ADDRESS HI
            sta   POINTH
            jsr   CHK
            jsr   GETBYT        ;GET ADDRESS LO
            sta   POINTL
            jsr   CHK
            txa                 ;IF CNT=0 DONT
            beq   ptpL3         ;GET ANY DATA
ptpL2:       
            jsr   GETBYT        ;GET DATA
            ldy   #$00
            sta   (POINTL),y    ;STORE DATA -- Y *must* be 0
            jsr   CHK
            
            ;; save last addr
            lda   POINTL
            sta   EAL
            lda   POINTH
            sta   EAH
            ;;
            
            jsr   INCPT         ;NEXT ADDRESS
            dex    
            bne   ptpL2
            inx                 ;X=1 DATA RCD X=0 LAST RCD
ptpL3:       
            jsr   GETBYT        ;COMPARE CHKSUM
            cmp   CHKHI
            bne   ptpL1
            jsr   GETBYT
            cmp   CHKSUM
            bne   ptpLoader
            txa                 ;X=0 LAST RECORD
            bne   ptpL0
ptpL8:
            jsr   putsil
            .byte SPC,CR,LF,"Paper tape read complete",CR,LF,0
            clc                 ; clear carry to indicate success
            rts
;
; ERROR?
ptpL1:      jsr   GETBYT        ;DUMMY Read
ptpLoader:  jsr   putsil
            .byte CR,LF,"Checksum error reading paper tape",CR,LF,0
            ; fallthrough
ptpError:
            sec                 ; set carry flag to indicate abort/error
            rts
; -------------------------------------------------------------------
ptpDumpxKim:
            jsr   ptpDump
            jsr   putsil 
            .byte "Complete.",CR,LF,0
            rts
            
cmppnt:
            lda   POINTH
            cmp   EAH
            bne   cmpdone
            lda   POINTL
            cmp   EAL
            bcs   cmpgte
            bcc   cmplt
cmpdone:
            bcs   cmpgte
cmplt:
            clc
            rts 
cmpgte:
            sec
            rts

.export ptpDump
ptpDump:
;       ** DUMP TO TTY FROM POINTL/POINTH TO EAL,EAH
                        
; START OF DUMP SUB
            lda   INL
            pha
            lda   INH
            pha
            lda   #$00
            sta   INL
            sta   INH       ; CLEAR RECORD COUNT
DUMP0:      
            lda   #$00
            sta   CHKHI     ; CLEAR CHKSUM
            sta   CHKSUM
            jsr   CRLF      ; PRINT CR LF
            lda   #$3B      ; PRINT SEMICOLON
            jsr   OUTCH
            lda   POINTL    ; TEST POINT GT OR ET
            cmp   EAL       ; HI LIMIT GOTO EXIT
            lda   POINTH
            sbc   EAH
            bcc   DUMP4
            clc
            lda   #$00      ; PRINT LAST RECORD
            jsr   PRTBYT    ; 0 BYTES
            ; Below is jsr   OPEN
            lda   INL
            sta   POINTL
            lda   INH
            sta   POINTH
            ;
            jsr   PRTPNT
            lda   CHKHI     ; PRINT CHKSUM
            jsr   PRTBYT    ; FOR LAST RECORD
            lda   CHKSUM
            jsr   PRTBYT
            ; Clear input buffer
            lda   #$00
            sta   INL
            sta   INH  
            ;
            pla 
            sta INH
            pla
            sta INL
            ; Return
            rts

DUMP4:
            lda   #$18      ; PRINT 24 BYTE COUNT
            tax             ; SAVE AS INDEX
            jsr   PRTBYT
            jsr   CHK
            jsr   PRTPNT
DUMP2:   
            ldy   #$00      ; PRINT 24 BYTES
            lda   (POINTL),Y ;  GET DATA
            jsr   PRTBYT    ; PRINT DATA
            jsr   CHK       ; COMPUTE CHKSUM
            jsr   INCPT     ; incREMENT POINT
            dex
            bne   DUMP2
            lda   CHKHI     ; PRINT CHKSUM
            jsr   PRTBYT
            lda   CHKSUM
            jsr   PRTBYT
            inc   INL       ;INCR RECORD COUNT
            bne   DUMP3
            inc   INH
DUMP3:
            jmp   DUMP0

;=====================================================
; Save address range to paper tape
ptpSave:
		jsr getAddrRange
		jsr putsil
		.byte CR,LF,"Saving addresses ",0
		lda SAH
		sta POINTH
		jsr PRTBYT
		lda SAL
		sta POINTL
		jsr PRTBYT
		
		jsr putsil 
		.asciiz " to "

		lda EAH
		jsr PRTBYT
		lda EAL
		jsr PRTBYT
		jsr putsil 
		
		.byte CR,LF,"Press any key to start, ESC to abort",CR,LF,0
		jsr xkimGetCH
		cmp #ESC
		beq ptpSaveAbort

		jsr ptpDump

		jsr putsil
		.byte CR,LF,"Save complete.",CR,LF,0
		jmp extKimLoop
ptpSaveAbort:
		jsr putsil
		.byte CR,LF,"Save aborted",CR,LF,0
		jmp extKimLoop