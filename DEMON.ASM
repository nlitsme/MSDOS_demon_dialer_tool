; required hardware:
;    - demon dialer, available from hacktic technoligies
;    - dtr line connected to hook switch, 1=off hook
;    - pulsedetector on  cts/rts line
;
;   rts=port+4 bit 1
;   dtr=port+4 bit 0
;   cts=port+6 bit 4
;
;  background
;  ctrl-shift -> popup menu
;  alt-shift -> macro keys
;  alt-esc   -> play phone nr at cursor pos
;

biosseg segment at 040h
org 0
  rs232portlist     dw 4 dup(?)           ; 0000
  lptaddr           dw 4 dup(?)           ; 0008
  hardwareinst      dw (?)                ; 0010
  post_status       db (?)                ; 0012
  basememsize       dw (?)                ; 0013
  scratch_1         dw (?)                ; 0015
  keystatus         dw (?)                ; 0017
  scratch_2         db (?)                ; 0019
  nextkeyptr        dw (?)                ; 001a
  nextfreeptr       dw (?)                ; 001c
  keybuffer         dw 010h dup (?)       ; 001e
  driverecalstat    db (?)                ; 003e
  drivemotorstat    db (?)                ; 003f
  drivemotoroffcnt  db (?)                ; 0040
  drivelastresult   db (?)                ; 0041
  drivecmd          db 7 dup(?)           ; 0042
  currvideomode     db (?)                ; 0049
  videocols         dw (?)                ; 004a
  videopagesize     dw (?)                ; 004c
  curpageofs        dw (?)                ; 004e
  cursorpos         dw 08h dup (?)        ; 0050
  cursortype        dw (?)                ; 0060
  currentpage       db (?)                ; 0062
  crtportaddr       dw (?)                ; 0063
  crtmodeselect     db (?)                ; 0065
  crtcgapallette    db (?)                ; 0066
  postresetreentry  dd (?)                ; 0067
  postlastirq       db (?)                ; 006b
  biostimerl        dw (?)                ; 006c
  biostimerh        dw (?)                ; 006e
  biostimeroverflow db (?)                ; 0070
  ctrlbreakflag     db (?)                ; 0071
biosseg ends

videoseg segment at 0b000h
videoseg ends

MAXPLAY equ 100

code  segment para 'CODE'
  assume  cs:code, ds:code, es:code, ss:code

org 0100h
start:
   jmp init

oldint08 label dword      ; timer interrupt
oldint08ofs label word
    dw (?)
oldint08seg label word
    dw (?)
oldint09 label dword      ; keyboard interrupt
oldint09ofs label word
    dw (?)
oldint09seg label word
    dw (?)
oldserint label dword      ; serial port interrupt
oldserintofs  label word
       dw (?)
oldserintseg  label word
       dw (?)
oldint10 label dword      ; video services
oldint10ofs  label word
       dw (?)
oldint10seg  label word
       dw (?)

rs232port label word
    dw (?)
serintmask label byte     ; defaults to com1/com3
    db 010h
serintno   label byte
    db 0ch
playing label byte        ; flag : string is being processed
    db 0
playpause label byte      ; flag : pause is in progress
    db 0
playstring label byte
    db MAXPLAY dup(0)
playptr label word        ; pointer into playstr
    dw  0
wakeupcount label byte    ; decrements to 0 -> wake up demon
    db  0
keyrelease label byte     ; 5-key released
    db  0
playuntilrelease label byte  ; flag set on 'x'
    db 0
hookflashcnt label byte   ; count down to off hook
    db 0
dialtonewait  label byte  ; count down to start tones
    db 0
inputstring label byte
    db 050h dup(?)
stringptr label dword
stringofs label word
    dw 0
stringseg label word
    dw 0
stringpos label word      ; position of cursor in string
    dw 0
stringlen label word
    dw 0
tikkenteller label word
    dw 0
tikdetect label byte      ; count down to eliminate tik-noise
    db 0
timerl  label word
    dw 0
timerh  label word
    dw 0
oldtimerl  label word
    dw 0
oldtimerh  label word
    dw 0

int09handler:
   jmp  int09

keyword label byte
   db   '_DeMoNm$'

int09:
   push ax
   push ds
   push  bx
   push  cx
   push  dx
   push  si
   push  di
   push  es

   mov  ax,seg biosseg
   mov  ds,ax
assume ds:biosseg
   test keystatus,01000h   ; scroll lock pressed
   je   testplay
   jmp  toggledtr
testplay:
   in   al,060h
   test  keystatus,02fh   ; no shift,alt,ctrl, numlock pressed
   jnz   goendint09
   cmp  al,04ch           ; grey 5
   je   processplaykey
   cmp  al,0cch           ; release grey 5
   je   releasekey

   ; space for other key processing
goendint09:
   jmp  endint09
releasekey:
   inc  cs:keyrelease
   jmp  goendint09
toggledtr:
   push dx
   mov dx,cs:rs232port
   add dx,4
   in  al,dx        ; toggle dtr line
   xor al,1
   out dx,al
   pop dx
   jmp endint09

processplaykey:
   cmp  cs:playing,0
   jne  goendint09
   mov  cs:keyrelease,0

   in   al,061h
   or   al,080h
   out  061h,al
   and  al,07fh
   out  061h,al    ; read key
   mov  al,020h    ; EOI
   out  020h,al
   call getcursorofs    ; bx=xpos, ds:si=cursorofs, dx=max-xpos
   mov  ax,cs
   mov  es,ax
assume ds:videoseg,  es:code
   mov  di,offset playstring   ; es:di = ptr to playstring
   mov  cx,MAXPLAY-1
   cld
getnumberloop:
   lodsw
   cmp al,' '
   jle endofnr
   cmp al,'.'
   je  endofnr
   cmp al,'-'
   je  skipchar
   stosb
skipchar:
   inc  bx            ; bx is cursor pos, dx is max cursor pos
   cmp  bx,dx
   jae  endofnr
   loop getnumberloop
endofnr:
   xor al,al
   stosb
   mov  ax,cs
   mov  ds,ax
assume ds:code
   xor  ax,ax
   mov  playptr,ax
   inc  playing
   pop  es
   pop  di
   pop  si
   pop  dx
   pop  cx
   pop  bx
   pop  ds
   pop  ax
   iret

endint09:
   pop  es
   pop  di
   pop  si
   pop  dx
   pop  cx
   pop  bx
   pop ds
   pop ax
   jmp  cs:oldint09

putbackstr:
assume ds:code
   mov  si,offset inputstring
   mov  cx,stringlen
   cld
outputloop:
   lodsb
   mov ah,0ah
   push cx
   mov cl,1
   mov bh,0
   int 010h
   pop  cx
   loop  outputloop
   ret

getinputline:
   call getcursorofs
assume ds:videoseg
   std
   mov  cx,bx
   inc  cx
locatestartloop:
   lodsw
   cmp  al,' '
   jle  foundstart
   cmp  al,'~'
   ja   foundstart
   loop locatestartloop
   cld
   lodsw
   jmp   copystr
foundstart:
   cld
   lodsw
   lodsw
copystr:
   sub  bx,cx
   sub  dx,cx
   mov  ax,ds
   mov  cs:stringseg,ax
   mov  cs:stringofs,si
   mov  cs:stringpos,bx     ; cursor offset in string
   mov  ax,cs
   mov  es,ax
assume es:code
   mov  cx,dx
   mov  di,offset inputstring
copystrloop:
   lodsw
   cmp  al,' '
   jle  endofstr
   cmp  al,'~'
   ja   endofstr
   stosb
   loop  copystrloop
endofstr:
   mov  cx,di
   sub  cx,offset inputstring
   mov  cs:stringlen,cx
   ret

getcursorofs:           ; bx=xpos, ds:si=cursorofs, dx,cx=max-xpos
   mov  ax,seg biosseg
   mov  ds,ax
assume ds:biosseg
   mov  bl,currentpage
   xor  bh,bh
   add  bx,bx
   mov  dx,cursorpos[bx]         ; x,y-position
   mov  cx,videocols
   mov  al,dh
   xor  dh,dh
   mov  bx,dx                  ; save x position in bx
   mul  cl
   add  dx,ax
   add  dx,dx
   add  dx,curpageofs
   mov  si,dx
   mov  dx,videocols
   mov  ax,seg videoseg
   mov  ds,ax              ; ds:si=ptr to cursor pos
   ret


int08handler:     ; timer interrupt
   push ax
   push ds
   push bx
   push dx
   mov  ax,cs
   mov  ds,ax
assume  ds:code
   cmp  tikdetect,0
   je   nextdecr
   dec  tikdetect
nextdecr:
   cmp  hookflashcnt,0
   jne  dechookcnt
   cmp  dialtonewait,0
   je   gotryplay
   dec  dialtonewait
   jmp  goendint08
dechookcnt:
   dec  hookflashcnt
   jne  goendint08
   mov dx,cs:rs232port
   add dx,4
   in  al,dx
   or  al,1      ; dtr=1: off hook
   out dx,al
   mov  dialtonewait,8
   jmp  goendint08
gotryplay:
   cmp  playing,0
   jne  playdigit
   dec  wakeupcount
   jne  goendint08
   mov  wakeupcount,50      ; wakeup every 2 seconds
   jmp  norelease           ; exec pause
goendint08:
   jmp  endint08
playdigit:
   xor playpause,1
   cmp playpause,0
   jne dopause

   mov  bx,playptr
   inc  playptr
   mov  al,playstring[bx]
   test al,al
   je   endofplay
   cmp  al,'0'
   jl   starpound
   cmp  al,'9'
   ja   alfabet
   sub  al,'0'
   jmp  transmit
starpound:
   cmp  al,'*'
   jne  poundsign
   mov  al,0ah
   jmp  transmit
poundsign:
   cmp  al,'#'
   jne  flashhook
   mov  al,0bh
   jmp  transmit
flashhook:
   cmp  al,'!'
   jne  illegalchar
   mov dx,cs:rs232port
   add dx,4
   in  al,dx
   and al,0feh   ; dtr=0: on hook
   out dx,al
   mov  hookflashcnt,8
   jmp  endint08
alfabet:
   cmp  al,'a'
   jl   uppercase
   cmp  al,'k'
   ja   specialchar
   sub  al,'a'
   add  al,011h
   jmp  transmit
specialchar:
   cmp  al,'x'
   jne  illegalchar
   inc  playuntilrelease
   jmp  dopause
uppercase:
   cmp  al,'A'
   jl   illegalchar
   cmp  al,'K'
   ja   illegalchar
   sub  al,'A'
   add  al,011h
   jmp  transmit
dopause:
   test  playuntilrelease,0ffh
   je    norelease
   xor   playpause,1      ; toggle pause back
   test  keyrelease,0ffh
   je    endint08
   dec   keyrelease
   dec   playuntilrelease
norelease:
   mov  al,0ffh
   jmp  transmit
endofplay:
   xor  al,al
   mov  playing,al
   mov  al,0ffh
transmit:
   mov  ah,al
   mov  dx,rs232port
   add  dx,5
waitxmitloop:
   in   al,dx
   test al,020h
   je   waitxmitloop
   mov  al,ah
   sub  dx,5
   out  dx,al      ; transmit character
illegalchar:
endint08:
   pop  dx
   pop  bx
   pop  ds
   pop  ax
   jmp  cs:oldint08

serinthandler:        ; tik interrupt
   push ax
   push bx
   push cx
   push dx
   push si
   push di
   push ds
   push es

   mov  ax,seg biosseg
   mov  es,ax
assume es:biosseg
   push cs
   pop  ds
assume ds:code

   mov  dx,rs232port
   add  dx,2
   in  al,dx
   test al,al          ; test MSR interupt
   jne  endserint
   add  dx,4
   in  al,dx
   test al,010h        ; test cts line
   jz   endserint
   cmp  tikdetect,0
   jne  endserint

   mov  tikdetect,2
   mov  ax,es:biostimerl
   mov  dx,es:biostimerh
   mov  timerl,ax
   mov  timerh,dx
   xchg ax,oldtimerl
   xchg dx,oldtimerh
   sub  timerl,ax
   sbb  timerh,dx

   inc  tikkenteller
   mov  ax,tikkenteller
   mov  di,098h
   call  prtdec
   mov  ax,timerl
   mov  di,088h
   call  prtdec

endserint:
   mov  al,020h
   out  020h,al
   pop  es
   pop  ds
   pop  di
   pop  si
   pop  dx
   pop  cx
   pop  bx
   pop  ax
   jmp  cs:[oldserint]

; convert ax -> ascii string and print at position di on topline of screen
prtdec:
    mov bx,0b000h
    mov es,bx
    mov bx,0ah
    mov cx,5
    std
convloop:
    xor dx,dx
    div  bx
    xchg dx,ax
    mov  ah,07h
    add  al,'0'
    stosw
    xchg dx,ax
    test ax,ax
    je   fillup
    loop convloop
    ret
fillup:
    mov ax,0720h
    rep stosw
    ret

int10handler:
   pushf
   call cs:[oldint10]
   push ax
   push bx
   push cx
   push dx
   push si
   push di
   push ds
   push es

   push cs
   pop  ds

   mov  ax,tikkenteller
   mov  di,098h
   call  prtdec
   mov  ax,timerl
   mov  di,088h
   call  prtdec

   pop  es
   pop  ds
   pop  di
   pop  si
   pop  dx
   pop  cx
   pop  bx
   pop  ax
   iret

; FROM HERE CODE IS DISCARDED AFTER INSTALLATION

init:
    mov ax,seg biosseg
    mov es,ax
assume es:biosseg
    mov dx,es:rs232portlist
    mov rs232port,dx
    mov ah,035h
    mov al,serintno
    int 021h
    mov  oldserintofs,bx
    mov  ax,es
    mov  oldserintseg,ax
    mov ax,03510h
    int 021h
    mov  oldint10ofs,bx
    mov  ax,es
    mov  oldint10seg,ax
    mov ax,03508h
    int 021h
    mov  oldint08ofs,bx
    mov  ax,es
    mov  oldint08seg,ax
    mov ax,03509h
    int 021h
    mov  oldint09ofs,bx
    mov  ax,es
    mov  oldint09seg,ax
assume es:code          ; actually of installed code
    mov  di,bx
    add  di,offset keyword - int09handler
    mov  si,offset keyword
    mov  cx,8
    cld
    repe cmpsb
    je   noinst
    inc  cx
noinst:
    push cx
    mov  si,080h      ; commandline string
    mov  bl,[si]
    xor  bh,bh
    inc  si
    mov  byte ptr [bx+si],0
    cld
skipspace:
    lodsb
    test  al,al
    je    endofargs
    cmp   al,' '
    je    skipspace
    cmp   al,'a'
    jl    testcmd
    cmp   al,'z'
    ja    testcmd
    and   al,0dfh
testcmd:
    mov   di,offset cmdlist
    mov   cx,offset cmdexec - cmdlist
    push  es
    push  cs
    pop   es
assume es:code
    repne  scasb
    jne    illegalcmd
    pop    es
    sub   di,offset cmdlist+1
    add   di,di
    jmp   cmdexec[di]
illegalcmd:
    pop   es
    mov   dx,offset strillcmd
exiterr:
    mov   ah,9
    int   021h
    mov   ax,04c01h
    int   021h
exitmsg:
    mov   ah,9
    int   021h
    mov   ax,04c00h
    int   021h
endofargs:
    jmp install
notinst:
    mov  dx,offset strnotins
    jmp  exiterr
uninstall:
    pop  ax
    test ax,ax
    jne  notinst
    cli
    mov   dx,es:oldint10ofs
    mov   ax,es:oldint10seg
    mov   ds,ax
    mov   ax,02510h
    int   021h
    mov   dx,es:oldserintofs
    mov   ax,es:oldserintseg
    mov   ds,ax
    mov   ah,025h
    mov   al,es:serintno
    int   021h
    mov   dx,es:oldint09ofs
    mov   ax,es:oldint09seg
    mov   ds,ax
    mov   ax,02509h
    int   021h
    mov   dx,es:oldint08ofs
    mov   ax,es:oldint08seg
    mov   ds,ax
    mov   ax,02508h
    int   021h

    push  es
    pop   ds
    in    al,021h
    or    al,serintmask      ; disable serial ints
    out   021h,al
    mov   dx,rs232port
    inc   dx
    in    al,dx
    and   al,0f7h
    out   dx,al            ; disable serial MSR int
    add   dx,3
    in    al,dx
    and   al,0f5h
    out   dx,al            ; rts=0,  out2=0
    sti
    mov   ah,049h        ; free psp  es:
    int   021h
    mov   ax,es:[02ch]
    mov   es,ax
    mov   ah,049h        ; free environment
    int   021h
    mov   ax,cs
    mov   ds,ax
    mov   dx,offset strremoved
goexitmsg:
    jmp   exitmsg

testinst:
    pop  ax
    mov  dx,offset strnotins
    test ax,ax
    jne  goexitmsg
    mov  dx,offset strinstcheck
    mov  ah,09
    int  021h
    mov  ax,es
    call wrhex
    mov  dx,offset streol
    jmp  exitmsg

portparam:
    mov  bx,1
    lodsb
    cmp  al,'0'
    jle  setport
    cmp  al,'4'
    ja   setport
    sub  al,'1'
    mov  bl,al
setport:
    add bx,bx
    push es
    mov ax,seg biosseg
    mov es,ax
assume es:biosseg
    mov dx,es:rs232portlist[bx]
    test dx,dx
    je  noport
    mov rs232port,dx
    pop  es
    jmp  install
noport:
    mov dx,offset strnoport
    jmp exiterr

allreadyinst:
    mov  dx,offset stralinst
    jmp  exiterr

install:
    pop  ax
    test ax,ax
    je   allreadyinst
    cli
    mov  dx,offset int09handler
    mov  ax,02509h
    int 021h
    mov  dx,offset int08handler
    mov  ax,02508h
    int 021h
    mov  dx,offset serinthandler
    mov  ah,025h
    mov  al,serintno
    int 021h
    mov  dx,offset int10handler
    mov  ax,02510h
    int 021h

    in al,021h
    mov ah,serintmask      ; enable serial interupts
    xor ah,0ffh
    and al,ah
    out 021h,al
    mov dx,rs232port
    inc dx
    in  al,dx
    or  al,08h       ; enable MSR interupts
    out dx,al
    add dx,3
    in  al,dx        ; rts+out2 line high
    or  al,0ah
    out dx,al
    add dx,2
    in  al,dx        ; reset MSR int flag

    sti
    mov dx,rs232port
    mov bx,dx
    add dx,3
    mov al,080h
    out dx,al        ; port+3      DLAB=1 : set baud speed
    xchg bx,dx
    mov al,7
    out dx,al        ; port
    inc dx
    xor al,al
    out dx,al        ; port+1   : 16384 baud
    xchg bx,dx
    mov  al,3
    out dx,al        ; port+3   : 8 N 1
    mov dx,offset strnowinst
    mov ah,09
    int 021h
    mov dx,offset init
    mov cl,4
    shr dx,cl
    inc dx
    mov ax,03100h
    int 021h

wrhex:
    push ax
    mov  al,ah
    call wrhexb
    pop  ax
wrhexb:
    aam  0ah
    push ax
    mov  al,ah
    call wrhexn
    pop  ax
wrhexn:
    mov ah,2
    add al,'0'
    cmp al,'9'
    jle outdigit
    add al,7
outdigit:
    mov dl,al
    int 021h
    ret

cmdlist label byte
    db  'UTP'
cmdexec label word
    dw  offset uninstall
    dw  offset testinst
    dw  offset portparam
strinstcheck label byte
    db  'DEMON is installed at segment $'
streol label byte
    db  0dh, 0ah, '$'
stralinst label byte
    db  'Already installed', 0dh, 0ah, '$'
strnowinst label byte
    db  'DEMON now installed', 0dh, 0ah, '$'
strremoved label byte
    db  'DEMON removed from memory', 0dh, 0ah, '$'
strnotins label byte
    db  'Not installed', 0dh, 0ah, '$'
strnoport label byte
    db  'Serial Port not available', 0dh, 0ah, '$'
strillcmd label byte
    db  'Invalid commandline option', 0dh, 0ah, '$'
code ends

end start

; to implement increment ...
;  - add output queue to keybd int : to insert backspaces + digits
;
