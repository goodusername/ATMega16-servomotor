; I release this code as public domain. Do with it what you will.
; Uses ATMEGA164P. Clock is set by external crystal to 20Mhz. You'll need to grab the include file two lines down from ATMEL.
START:
.INCLUDE "m164Pdef.inc"

; General info
; PortA, B, and C have 8 available pins each
; PortD is reserved for external control signals, but some pins can be used
; Command set:
; 0x01 read new commands
; 0xFE delimiter between command parts
; 0x00, 0x02-0xFD, 0xFF are the safest command space, but you can use 0x00-0xFF
; To control: send 0x01, then the fist servomotor value, then 0xFE, then the second one
; Supports 50Hz digital servos, the valid position values for each depends on servo specifications. It's quick to figure out with trial and error.

; Register Descriptions
; r0 is the first servomotor PWM register
; r1 is the second servomotor PWM register
; r16-r17 are general purpose registers

; Notes
; To control lots more servos+other things, just change the command structure to 0x01,servo address,0xFE,position value. I'll do this in the next revision.

; Setup
; Make sure some key registers are cleared
ldi r16, 0x00
mov r0, r16
mov r1, r16

; Set data direction on ports 

ldi r16, 0xFF
OUT DDRB, r16 ; PORTB output
ldi r17, 0xFF
clr r27

; Configure USART. Baudrate 9.6kbaud. By changing the crysta' frequency, faster speeds could be supported, but this is fine for now.

ldi r16, (1 << RXEN0) | (0 << TXEN0)
STS UCSR0B, r16
ldi r16, (1 << UCSZ01) | (1 << UCSZ00)
STS UCSR0C, r16
clr r16
STS UBRR0H, r16
ldi r16, 0x81; Magic number is decimal 129 for baudrate 9.6k baud
STS UBRR0L, r16

; Enable 16 bit timer, prescaler 8:

ldi r16, (0<<CS12 | 1<<CS11) | (0<<CS00) | (1<<WGM12) | (1<<WGM13)
sts TCCR1B,r16
;set max value so we get 50hz:
ldi r16, 0xC3
sts ICR1H, r16
ldi r16, 0x50
sts ICR1L, r16	

; Enable 8 bit timer, with seperate prescaler :
ldi r16, (1<<CS02 | 0<<CS01) | (0<<CS00)		
out TCCR0B, r16

main:

; PortB pin0+1 servo control

sbis TIFR1, 5 ;Check if it's time to start a new servo cycle at 50Hz 
rjmp nons0
ons0:
clr r16
cp r16, r0
breq ons1
SBI PORTB, 0 ; Start on cycle servo 0
ons1:
cp r16, r1
breq ons2
SBI PORTB, 1 ; Start on cycle servo 1
ons2:
clr r16
out TCNT0, r16
sbi TIFR1, 5
nons0:
in r16, TCNT0 ;see if it's time to turn servo 0 off
CP r16, r0 
brsh off0
rjmp nons1
off0:
cbi PORTB, 0
nons1:
in r16, TCNT0 ;see if it's time to turn servo 1 off
CP r16, r1 
brsh off1
rjmp check_com
off1:
cbi PORTB, 1

check_com:

; Check for new commands. Commands available if 0x01 is received, register/value delimiter is 0xFE. 

cpi r26, 0x01
breq newdata
cpi r26, 0x03
breq powerlevel
LDS r17, UCSR0A

; check if any data has been received. If not, go back to work.

sbrs r17, 7 
rjmp main
LDS r17, UDR0 

; Make sure the received data is the start of a valid command set (0x01). If not, go back to work.

cpi r17, 0x01 
breq newdata 
rjmp main
newdata:

; Since we know we are going to receive a command, we can skip previous steps on next round, we have set the new data received flag r26 to 0x01	

ldi r26, 0x01
LDS r17, UCSR0A
sbrs r17, 7
rjmp main
address:
LDS r17, UDR0
cpi r17, 0xFE
breq powerlevel
mov r18, r17
rjmp main
powerlevel:
ldi r26, 0x03
LDS r17, UCSR0A
sbrs r17, 7
rjmp main
LDS r17, UDR0
mov r19, r17
clr r26

; Load servo1 command

mov r0, r19


; Load servo2 command

mov r1, r18
rjmp main
