biosseg segment at 040h
  org 06ch
  biostimerl dw (?)
  biostimerh dw (?)
  org 08h
  lptaddr dw (?)
biosseg ends

code  segment para 'CODE'
org 0100h
  assume  cs:code, ds:code, es:code, ss:code

start:
   jmp init

;   port+2.4 : irq enable
;   port+1.6 : ack
;   int0f : hardware int
;   port21&=0x7f -> enable int

oldint0f label dword
oldint0fofs  label word
       dw (?)
oldint0fseg  label word
       dw (?)
oldint10 label dword
oldint10ofs  label word
       dw (?)
oldint10seg  label word
       dw (?)
lpt1port label word
       dw (?)

tikkenteller label word
       dw 0
timerl  label word
       dw 0
timerh  label word
       dw 0
oldtimerl  label word
       dw 0
oldtimerh  label word
       dw 0

int0fhandler:
   jmp  inthnd
keyword  label byte
   db   '_TIKKEN$'

inthnd:
   push ax
   push bx
   push cx
   push dx
   push si
   push di
   push ds
   push es

   mov  dx,lpt1port
   inc  dx
   in  al,dx
   test al,040h   ; don't count release
   jne  endofint

   mov  ax,seg biosseg
   mov  ds,ax
assume ds:biosseg
   mov  ax,biostimerl
   mov  dx,biostimerh
   push cs
   pop  ds
assume ds:code
   mov  bx,oldtimerh
   cmp  dx,bx
   jne  inctik
   mov  bx,oldtimerl   ; no new tik within .1 second possible
   add  bx,2
   cmp  ax,bx
   jl   endofint
 inctik:
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

endofint:
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
   jmp  cs:[oldint0f]

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

; from here code is discarded after installation

init:
   mov  ax,seg biosseg
   mov  es,ax
   mov  ax,es:lptaddr
   mov  lpt1port,ax
   mov  ax,03510h
   int  021h
   mov  oldint10ofs,bx
   mov  ax,es
   mov  oldint10seg,ax
   mov  ax,0350fh
   int  021h
   mov  oldint0fofs,bx
   mov  ax,es
   mov  oldint0fseg,ax
   mov  di,bx
   add  di,3
   mov  si,offset keyword
   mov  cx,8
   cld
   repe cmpsb
   je   noinst
   inc  cx

noinst:
   mov  si,080h
   cmp  byte ptr [si],2
   jae  processcmd
   jmp  install
processcmd:
   mov  al, [si+2]
   and  al,0dfh
   xor  bx,bx
cmdscanloop:
   cmp  bx,ncmds
   jae  help
   cmp  al,cmdtab[bx]
   je   foundcmd
   inc  bx
   jmp  cmdscanloop
foundcmd:
   add bx,bx
   jmp  cmdjmp[bx]

; invalid option

help:
   mov  dx,offset helptext
exitmsg:
   mov  ah,09
   int  021h
exit:
   mov  ax,4c00h
   int  021h

; T option

testinstall:
   test  cx,cx
   je    isinst
notinst:
   mov  dx,offset errnotinst
   jmp  exitmsg
isinst:
   mov  dx,offset msgisinst
   jmp  exitmsg
alreadyinst:
   mov  dx,offset erralreadyinst
   jmp  exitmsg

; U option

deinstall:
   test  cx,cx
   jne   notinst
   mov   dx,es:oldint0fofs
   mov   ax,es:oldint0fseg
   mov   ds,ax
   mov   ax,0250fh
   int   021h
   mov   dx,es:oldint10ofs
   mov   ax,es:oldint10seg
   mov   ds,ax
   mov   ax,02510h
   int   021h
   sti
   in    al,021h
   or    al,080h
   out   021h,al
   mov   dx,lpt1port
   add   dx,2
   in    al,dx
   and   al,0efh
   out   dx,al
   cli
   mov   ah,049h        ; free psp  es:
   int   021h
   mov   ax,es:[02ch]
   mov   es,ax
   mov   ah,049h        ; free environment
   int   021h
   mov   ax,cs
   mov   ds,ax
   mov   dx,offset deinstalled
   jmp   exitmsg

; I option

install:
   test  cx,cx
   je    alreadyinst
   mov dx, offset int0fhandler
   mov ax,0250fh
   int 021h
   mov dx, offset int10handler
   mov ax,02510h
   int 021h
   sti   
   in al,021h
   and al,07fh
   out 021h,al
   mov dx,lpt1port
   add dx,2
   in  al,dx
   or  al,010h
   out dx,al
   cli
   mov dx, offset instmsg
   mov ah,09
   int 021h
   mov dx,offset init
   mov cl,4
   shr dx,cl
   inc dx
   mov ax,03100h
   int 021h

; C option
clearcounter:
   test cx,cx
   je clearcntr1
   jmp notinst
clearcntr1:
   xor ax,ax
   mov  es:tikkenteller,ax
   mov  dx,offset cntcleared
   jmp  exitmsg

helptext label byte
   db  'Usage: tikken [uti]', 0dh, 0ah
   db  '   u = uninstall', 0dh, 0ah
   db  '   t = test installation', 0dh, 0ah
   db  '   c = clear counter', 0dh, 0ah
   db  '   i = install', 0dh,0ah, '$'
errnotinst label byte
   db  'Not installed', 0dh, 0ah, '$'
erralreadyinst label byte
   db  'Already installed', 0dh, 0ah, '$'
instmsg label byte
   db  'Tikken now installed', 0dh, 0ah, '$'
deinstalled label byte
   db  'Tikken removed from memory', 0dh, 0ah, '$'
msgisinst label byte
   db  'installed', 0dh, 0ah, '$'
cntcleared label byte
   db  'Counter cleared', 0dh, 0ah, '$'
ncmds label word
   dw  offset cmdjmp - cmdtab
cmdtab label byte
   db  'UTIC'
cmdjmp label word
   dw  offset deinstall
   dw  offset testinstall
   dw  offset install
   dw  offset clearcounter
code ends
   end   start
