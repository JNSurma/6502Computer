
vidpage = $0000 ; 2 bytes
start_color = $0002 ; 1 byte
value = $0200    ; 2 bytes
mod10 = $0202    ; 2 bytes
message = $0204  ; 6 bytes
counter = $020a  ; 2 bytes

PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
PCR = $600c
IFR = $600d
IER = $600e



E  = %10000000
RW = %01000000
RS = %00100000

	.org $8000
	
reset:
  ldx #$ff
  txs
  cli
  
  lda #$82
  sta IER
  lda #$00
  sta PCR

  lda #%11111111 ; Set all pins on port B to output
  sta DDRB
  lda #%11100000 ; Set top 3 pins on port A to output
  sta DDRA

  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001100 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction

  lda #0
  sta counter
  sta counter + 1

	lda #$0
	sta start_color
	
loop:
	;initialize vidpage to beginning of video ram $2000
	lda #$20
	sta vidpage + 1
	lda #$00
	sta vidpage
	
	ldx #$20 ; X will count down how many pages of video RAM to go
	ldy #$0 ; populate a page starting at 0
	inc start_color
	lda start_color ; color of pixel
	
page:
	sta (vidpage),y ; write A register to address vidpage + y
	
	and #$7f ; if we cycled through 127 colors
	bne inc_color
	clc
	adc #$1 ; increment twice
	
inc_color:
	clc
	adc #$1 ;otherwise increment pixel color value just once
	
	
	iny
	bne page
	
	inc vidpage + 1 ; skip to the next page
	dex
	bne page ; keep going through $20 pages

  lda #%00000010 ; Home
  jsr lcd_instruction

  lda #0
  sta message
  
  ; Initialize value to be the number to convert 
  lda counter
  sta value
  lda counter + 1
  sta value + 1

divide:  
  ; Initialize the remainder to zero
  lda #0
  sta mod10
  sta mod10 + 1
  clc
  
  ldx #16
divloop:
  ; Rotating quotient and remainder
  rol value
  rol value + 1
  rol mod10
  rol mod10 + 1
  
  ; a,y = dividend - divisor
  sec
  lda mod10
  sbc #10
  tay ;save low byte in Y
  lda mod10 + 1
  sbc #0
  bcc ignore_result ; branch if dividend < divisor
  sty mod10
  sta mod10 + 1
  
ignore_result:
  dex
  bne divloop
  rol value ; shift in the last bit of the quotient
  rol value + 1
  
  lda mod10
  clc
  adc #"0"
  jsr push_char

  ; if value !- 0, then continue dividing
  lda value
  ora value +1
  bne divide ; branch if value != 0

  ldx #0
print:
  lda message,x
  beq endloop
  jsr print_char
  inx
  jmp print
  

number: .word 1729

; Add the character in the A register to the beginning of the
; null-terminated string `message`

push_char:
  pha ; Push new first char onto stack
  ldy #0	

endloop:
	jmp loop

  
char_loop:  
  lda message,y ; Get char on string and put into X
  tax
  pla
  sta message,y ; Pull char off stack and add it to the string
  iny
  txa
  pha           ; Push char from string onto stack
  bne char_loop
  
  pla
  sta message,y ; Pull the null off the stack and add to the end of the string
  
  rts

lcd_wait:
  pha
  lda #%00000000  ; Port B is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta PORTA
  lda #%11111111  ; Port B is output
  sta DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  lda #E         ; Set E bit to send instruction
  sta PORTA
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  rts

print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS         ; Set RS; Clear RW/E bits
  sta PORTA
  lda #(RS | E)   ; Set E bit to send instruction
  sta PORTA
  lda #RS         ; Clear E bits
  sta PORTA
  rts

nmi:
irq:
  pha
  txa
  pha
  tya
  pha
  
  inc counter
  bne exit_irq
  inc counter + 1
exit_irq:
  ;delay
  ldy #$80
  ldx #$ff
delay:
  dex
  bne delay
  dey
  bne delay
  
  bit PORTA ;Read PORTA to clear interrupt before returning from interrupt

  pla
  tay
  pla
  tax
  pla
  rti
	
	
; Reset/IRQ/NMI vectors
	.org $fffa
	.word nmi
	.word reset
	.word irq