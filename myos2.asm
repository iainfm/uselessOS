	VEC_IRQ_BRK = &FFFE
	VEC_RESET   = &FFFC
	VEC_NMI     = &FFFA
	BEGIN       = &C000 ; &C000 OS ROM test ; &6000 RAM test

	SystemVIA = &FE40
	UserVIA   = &FE60 \\ Ports: A=printer B=user
	CrtcReg   = &FE00
	CrtcVal   = &FE01

	ViaRegB = 0  \\ RegB
	ViaRegH = 1  \\ Handshake RegA
	ViaDDRB = 2  \\ controls which bits are write (1) and read (0) in RegB
	ViaDDRA = 3  \\ controls which bits are write (1) and read (0) in RegA

	ViaACR  = 11 \\ Auxiliary Control Register
	ViaPCR  = 12 \\ Periferal Control Register
	ViaIFR  = 13 \\ Interrupt Flag    Register // b7:any/all   b6:timer1 b5:timer2 b4:CB1 b3:CB2 b2:ShiftReg B1:CA1 b0:CA2
	ViaIER  = 14 \\ Interrupt Enable  Register // b7:1set1s/0clear1s b2:shift-reg (8)
	ViaRegA = 15 \\ No hadshake RegA

	SysViaRegB = SystemVIA+ViaRegB \\ 0 b0..b2 addressable latch bit, b3 value to write, b4,b5 joystick-buttons b6 speech-ready b7 speech-interrupt
	                               \\   B0 Sound write enable, B1 Read select speech, B2 write select speech, B3 keyboard write enable
							       \\   B4,B5 screen wrap address (&8000-size) 11:20K, 00:16K, 10:10K, 01:8K, B6 Caps Lock LED B7 Shift Lock LED
	SysViaDDRB = SystemVIA+ViaDDRB \\ 2 controls which bits are write (1) and read (0) in RegB
	SysViaDDRA = SystemVIA+ViaDDRA \\ 3 controls which bits are write (1) and read (0) in RegA (slow data bus)
	
	SysViaACR  = SystemVIA+ViaACR  \\ B Auxiliary Control Register
	SysViaPCR  = SystemVIA+ViaPCR  \\ C Periferal Control Register
	SysViaIFR  = SystemVIA+ViaIFR  \\ D Interrupt Flag    Register // b7:any/all   b6:timer1 b5:timer2 b4:CB1-ADC-EndOfConv b3:CB2-light-pen-strobe * (AUG414)
	SysViaIER  = SystemVIA+ViaIER  \\ E Interrupt Enable  Register // b7:1set1s/0clear1s b2:shift-reg (8) b1:CA1-6845-vsync b0CA2-keyboard-keypress
	SysViaRegA = SystemVIA+ViaRegA \\ F No hadshake RegA (good for keyboard) - Access slow data bus connection (RegB-B0-B3) and read/write (DDRA)

	
	UsrViaDDRB = UserVIA+ViaDDRB \\ 2 controls which bits are write (1) and read (0) in RegB
	UsrViaDDRA = UserVIA+ViaDDRA \\ 3 controls which bits are write (1) and read (0) in RegA
	UsrViaIFR  = UserVIA+ViaIFR  \\ D Interrupt Flag    Register
	UsrViaIER  = UserVIA+ViaIER  \\ E Interrupt Enable  Register
	
	title_pos   = &7C28

ORG BEGIN

.MAIN
.reset
	SEI
	CLD

.op_reset
	lda #&7F : sta SysViaIER : sta SysViaIFR \\ disable and clear all interrupts
	           sta UsrViaIER : sta UsrViaIFR \\ disable and clear all interrupts
	lda #&FF : sta SysViaDDRA : sta SysViaDDRB
	           sta UsrViaDDRA : sta UsrViaDDRB
	lda #4   : sta SysViaPCR  \\ vsync \\ CA1 negative-active-edge CA2 input-positive-active-edge CB1 negative-active-edge CB2 input-nagative-active-edge
	lda #0   : sta SysViaACR  \\ none  \\ PA latch-disable PB latch-disable SRC disabled T2 timed-interrupt T1 interrupt-t1-loaded PB7 disabled

\\	disable all SysViaRegB B bits

	ldy #&0F
	sty SysViaDDRB
.lp
	sty SysViaRegB
	dey
	cpy #9
	bcs lp


\\ silence all channels

	lda #&FF : sta SysViaDDRA

	clc : lda #%10011111      \\ silence channel 0

.lpa
	sta SysViaRegA            \\ sample says SysViaRegH but OS uses no handshake \\ handshake regA
	ldy #0+0 : sty SysViaRegB \\ enable sound for 8us
	PHA : PHA : NOP : NOP     \\ 2(sta/2) + 3+3+2+2 + 2(lda #)+2(sta/2) = 16 clocks = 8us
	ldy #0+8 : sty SysViaRegB \\ disable sound
	adc #&20 : bcc lpa

.clear_mode_7                 \\ Assume MODE 7 for the time being

	ldy #0
.lpc
	FOR page, 0, &300, &100
		lda #&20 : sta &7C00+page,y
	NEXT
	iny : bne lpc
	
\ Display OS title
    LDY     #&00
.title_loop
    LDA     title,Y
	BEQ     end_title_loop
	STA     title_pos,Y
	INY
	JMP     title_loop
	
.end_title_loop
	ldy #17
	
.m7lp
	lda mode_7_setup,y
	sty CrtcReg : sta CrtcVal
	dey : bpl m7lp

.halt
	jmp halt \ that's all folks

.irq_brk
.nmi
.title 
	EQUS "Useless OS 0.1"
	EQUB 0
	
.mode_7_setup : EQUB &3F, &28, &33, &24, &1E, &02, &19, &1C, &93, &12, &72, &13, &28, &00, 0,0, &28, &00 ;; HI(((title) - &74) EOR &20), LO(title)


IF * > &C000
	ORG VEC_NMI     ; &FFFA
	EQUW nmi
	ORG VEC_RESET   ; &FFFC
	EQUW reset
	ORG VEC_IRQ_BRK ; &FFFE
	EQUW irq_brk
ENDIF

.END

PRINT ~BEGIN, "..", ~END, "Run", ~MAIN
SAVE "myos.rom", BEGIN, END, MAIN
