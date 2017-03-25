*-----------------------------------------------------------
* Title      : Disassembler Program
* Written by : Denise Moran, 1367222
* Date       : 03/10/2017
* Description: 422 Final Project Wi17 UW Bothell
*-----------------------------------------------------------
* NOTES:
* $00 = saves start location
* $10 = saves end location
* $20 = screen line counter
* $30 = MOVE size
* $40 = MOVEA status

START	ORG    	$1000			*Origin of memory at $1000

********************************************************************************
*==================================== User Input =============================== 
********************************************************************************
inputStart:
	JSR		clearScreen
	JSR		clearRegisters
	MOVE.L	#0,D6
	LEA		Prmpt0,A1				*prompt msg for starting memory
	JSR		print
	MOVE.L	#$00,D2					*input -> $00
	JSR		stringInput_iD2
	JSR		printNl
	BRA		chkStart
inputEnd:
	JSR		clearScreen
	JSR		clearRegisters
	MOVE.L	#1,D6
	LEA		Prmpt1,A1				*prompt msg for starting memory
	JSR		print
	MOVE.L	#$10,D2					*input -> $10
	JSR		stringInput_iD2
	JSR		printNl
	CLR.L	D2
	BRA		chkEnd
afterInput:	
	MOVEA.L	$00,A0
	MOVE.L	$10,A2
	MOVE.W	$0,$20
********************************************************************************
*===================================  Disassembler ============================= 
********************************************************************************
LOOP:
	JSR		atEnd					*stops at end location
	JSR		lineCount				*pauses screen if full
	JSR		clearRegisters			*clear all data registers
	JSR		printLocation			*prints memory location first
	MOVE.W	(A0)+,D1				*moves next opcode word ito D1
	JSR		isolateLeadBits
	CMP		#$1,D2					*MOVE.B
	BEQ		lead1
	CMP		#$2,D2					*MOVE.L
	BEQ		lead2
	CMP		#$3,D2					*MOVE.W
	BEQ		lead3
	CMP		#$4,D2					*NOP,RTS,CLR
    BEQ		lead4
	BRA		unknown					*cannot decode
**************************************************
*============ Disassembler Subroutines =========== 
**************************************************
*--- General subroutines ---
*ends program if end location reached
atEnd:
	CMPA.L	A0,A2
	BLE		inputAgain
	RTS
*cannot match opcode pattern
unknown:		
	LEA		UK,A1					*prints 'DATA $'
	JSR		print
	JSR		printHex				*prints data at current location
	JSR		printNL
	BRA		LOOP					*read next word
**************************************************
* Disassembler matching subroutines
**************************************************
*disassembles MOVE.B
lead1:
	MOVE.B	#0,$30					*save size in $30
	BRA		chkMOVE
*disassembles MOVE.L
lead2:
	MOVE.B	#2,$30					*save size in $30
	BRA		chkMOVEA				*MOVEA
*disassembles MOVE.W
lead3:
	MOVE.B	#1,$30					*save size in $30
	BRA		chkMOVEA				*MOVEA
*disassembles NOP,RTS,CLR,LEA
lead4:
	CMP		#$4E71,D1				*NOP 
	BEQ		printNOP
	CMP		#$4E75,D1				*RTS 
	BEQ		printRTS
	BRA		chkCLR					*CLR
notCLR
	BRA		chkLEA					*LEA
notLEA
	BRA		unknown
**************************************************
* Disassembler checking subroutines
**************************************************
*MOVE verification
chkMOVE:
	JSR		getEA_bits5_0_D3_D4		*check valid ea values (any)
	JSR		chkEA
	CMP		#1,D5
	BEQ		unknown
	JSR		getEA_bits11_6_D4_D3 	*check valid ea values (data addressable)
	JSR		chkEA_DA_D3
	CMP		#1,D5
	BEQ		unknown
	BRA		printMOVE
*MOVEA verification
chkMOVEA:
	JSR		isolateBits_8_6_D2		*check 8-6 == 1
	CMP		#1,D2
	BNE		chkMOVE
	MOVE.B	#1,$40					*indicates to print 'A'
	JSR		getEA_bits5_0_D3_D4		*check valid ea values (any)
	JSR		chkEA
	CMP		#1,D5
	BEQ		unknown
	BRA		printMOVE
*CLR verification
chkCLR:
	JSR		isolateBits_11_8_D2		*check 11-8 == 2
	CMP		#2,D2
	BNE		notCLR
	JSR		isolateBits_7_6_D2		*check valid size	
	JSR		chkSize_D2
	CMP		#1,D5
	BEQ		unknown
	JSR		getEA_bits5_0_D3_D4		*check valid ea values (data addressable)
	JSR		chkEA_DA_D3			
	CMP		#1,D5
	BEQ		unknown
	BRA		printCLR				*print to screen
*LEA verification
chkLEA:
	JSR		isolateBits_8_6_D2		*check 8-6 == 7
	CMP		#7,D2
	BNE		notLEA
	JSR		getEA_bits5_0_D3_D4	*check valid ea values (control address)
	JSR		chkEA_CA_D3			
	CMP		#1,D5
	BEQ		unknown
	BRA		printLEA
*checks if EA mode(D3) and register(D4) is valid, all addresing modes (except 5 & 6)
chkEA:
	MOVE.L	#0,D5					*D5=1 indicates fail
	CMP		#5,D3					*not 5; (d16,An)
	BNE		p0
	MOVE.B	#1,D5
p0	CMP		#6,D3					*not 6; (d16,An,Xn)
	BNE		p1
	MOVE.B	#1,D5
p1	RTS
*checks if data addressable EA mode(D3) and register(D4) is valid
chkEA_DA_D3:
	MOVE.L	#0,D5					*D5=1 indicates fail
	CMP		#1,D3					*not 1; An
	BNE		p2
	MOVE.B	#1,D5
p2	CMP		#5,D3					*not 5; (d16,An)
	BNE		p3
	MOVE.B	#1,D5
p3	CMP		#6,D3					*not 6; (d16,An,Xn)
	BNE		p4
	MOVE.B	#1,D5
p4	CMP		#7,D3					*mode 7 (absolute), check register < 2
	BEQ		chkEA_DA_abs
return_chkEA_DA
	RTS
*checks if control addressing EA mode(D3) and register(D4) is valid
chkEA_CA_D3:
	MOVE.L	#0,D5					*D5=1 indicates fail
	CMP		#1,D3					*mode > 1; not Dn or An
	BGT		p5
	MOVE.B	#1,D5
p5	CMP		#3,D3					*mode not 3; (An)+
	BNE		p6
	MOVE.B	#1,D5			
p6	CMP		#4,D3					*mode not 4; -(An)
	BNE		p7
	MOVE.B	#1,D5
p7	CMP		#5,D3					*mode not 5; (d16,An)
	BNE		p8
	MOVE.B	#1,D5
p8	CMP		#6,D3					*mode not 6; (d16,An,Xn)
	BNE		p9
	MOVE.B	#1,D5
p9	CMP		#7,D3					*mode 7 (absolute), check register < 2
	BEQ		chkEA_CA_abs
return_chkEA_CA
	RTS
*if(mode=7 AND control address ea)checks if register(D4) is < 2 (no immediate data)
chkEA_DA_abs:
	CMP		#2,D4					*register < 2
	BLT		p10
	MOVE.B	#1,D5
p10	BRA		return_chkEA_DA
*if(mode=7)checks if register(D4) is < 2 (no immediate data)
chkEA_CA_abs:
	CMP		#2,D4					*register < 2
	BLT		p11
	MOVE.B	#1,D5
p11	BRA		return_chkEA_CA
*checks if size (byte in D2) is valid, fail indicated by D5=1
chkSize_D2:
	CLR.L	D5
	CMP		#3,D2
	BLT		p12
	MOVE.B	#1,D5
p12	RTS
**************************************************
* Disassembler bit isolation subroutines
**************************************************
*isolates lead 4 bits (15-12) into D2
isolateLeadBits:
	MOVE.W	D1,D2
	MOVE.B	#12,D3
	LSR.W	D3,D2
	CLR.L	D3
	RTS
*isolates EA mode from bits 5-0. returns EA mode in D3, register in D4
getEA_bits5_0_D3_D4:
	MOVE.L	D1,D3
	JSR		isolateBits_5_3_D3
	MOVE.L	D1,D4
	JSR		isolateBits_2_0_D4
	RTS
*isolates EA mode from bits 11-6. returns EA mode in D3, register in D4
getEA_bits11_6_D4_D3:
	JSR		isolateBits_11_9_D2		*D4=register
	MOVE.L	D2,D4
	JSR		isolateBits_8_6_D2		*D3=mode
	MOVE.L	D2,D3
	RTS
*isolates bits 11,10,9 in D2
isolateBits_11_9_D2:
	MOVE.L	D1,D2
	LSL.W	#4,D2
	MOVE.L	#13,D3
	LSR.W	D3,D2
	CLR.L	D3
	RTS
*isolates bits 11,10,9 in D2, used for verifying CLR pattern
isolateBits_11_8_D2:
	MOVE.L	D1,D2	
	LSL.W	#4,D2				
	MOVE.B	#12,D3
	LSR.W	D3,D2
	CLR.L	D3
	RTS
*isolates bits 11,10,9 into D2
isolateBits_8_6_D2:
	MOVE.L	D1,D2	
	LSL.W	#7,D2				
	MOVE.B	#13,D3
	LSR.W	D3,D2
	CLR.L	D3
	RTS
*isolates bits 7,6 in D2, used for size
isolateBits_7_6_D2:
	MOVE.L	D1,D2
	LSL.W	#8,D2
	MOVE.L	#14,D3
	LSR.W	D3,D2
	CLR.L	D3
	RTS
*isolates bits 5,4,3 in D3, used for EA mode
isolateBits_5_3_D3:
	MOVE.B	#10,D4
	LSL.W	D4,D3
	MOVE.B	#13,D4
	LSR.W	D4,D3
	CLR.L	D4
	RTS	
*isolates bits 2,1,0 in D4, used for EA register
isolateBits_2_0_D4:
	MOVE.B	#13,D5
	LSL.W	D5,D4
	LSR.W	D5,D4
	CLR		D5
	RTS		
**************************************************
* Disassembler I/O subroutines
**************************************************
*prompts user to use disassembler again
inputAgain:
	JSR     clearRegisters
	LEA     Prmpt2,A1				*prompts user to read again
	JSR		print
	MOVE.B  #5,D0					*Reads 1 char from keyboard
	TRAP    #15         
	CMP.B   #$59,D1					*User types Y/y, restarts program
	BEQ     inputStart
	CMP.B   #$79,D1
	BEQ     inputStart
	CMP.B   #$4E,D1					*User types N/n, ends program
	BEQ     endProgram
	CMP.B   #$6E,D1
	BEQ     endProgram
	JSR		printNL
	LEA     ErrMsg0,A1				*invalid entry
	JSR		print
	JSR		waitForEnter
	BRA     inputAgain
**************************************************
* Print instruction subroutines
**************************************************
*used to print location before data, assumes location is in D1
printLocation:
	MOVE.W	A0,D1					*print current memory address
	JSR		printHex
    LEA		tb,A1
    JSR		print
    RTS
*prints MOVE label, size, source ea and destination ea
printMOVE:
	LEA		OpMOVE,A1				*print MOVE							
	JSR		print
	MOVE.B	$30,D2
	JSR		printA					*prints 'A' if MOVEA
	JSR		printSize				*print size
	LEA		SP1,A1
	JSR		print
	CMP		#1,D6					*prints only 1 space if  MOVEA
	BEQ		one
	JSR		print
one	JSR		getEA_bits5_0_D3_D4		*print source EA
	JSR		printEA
	JSR		printCMA
	JSR		getEA_bits11_6_D4_D3	*print destination EA
	JSR		printEA
	JSR		printNL
	MOVE.B	#0,$30					*clear size
	BRA		LOOP
*prints NOP label
printNOP:
	LEA		OpNOP,A1
	JSR		print
	BRA		LOOP
*prints RTS label
printRTS:
	LEA		OpRts,A1
	JSR		print
	BRA		LOOP
*prints CLR label, size and ea
printCLR:
	LEA		OpClr,A1				*print label
	JSR		print
	JSR		printSize				*print size
	LEA		SP3,A1
	JSR		print
	JSR 	printEA					*print EA
	JSR		printNL
	BRA		LOOP
*prints LEA label, size and source ea
printLEA:
	LEA		OpLEA,A1				*print label
	JSR		print
	JSR		printTAB
	JSR		getEA_bits5_0_D3_D4
	JSR		printEA					*print EA
	JSR		printCMA
	JSR		isolateBits_11_9_D2		*get destination address register
	MOVE.B	#1,D3					*An mode
	MOVE.L	D2,D4
	JSR		printEA
	JSR		printNL
	BRA		LOOP
*Prints effective address, mode=D3, register=D4
printEA:
	MOVE.L	D1,D6					*save opcode in D6
	MOVE.L	D4,D1
	CMP		#0,D3
	BEQ		printDataReg			*Dn
	CMP		#1,D3
	BEQ		printAddrReg			*An
	CMP		#2,D3
	BEQ		printAddrRegInd			*(An)
	CMP		#3,D3
	BEQ		printAddrRegPostIncr 	*(An)+
	CMP		#4,D3
	BEQ		printAddrRegPreDecr		*-(An)
	CMP		#7,D3
	BEQ		printAbsoluteAddr		*-(An)
return_printEA
	MOVE.L	D6,D1
	CLR.L	D6
	RTS
*prints data register direct mode to screen, register value stored in D4
printDataReg:
	LEA		Dn,A1					*prints 'D'
	JSR		print
	JSR		printHex				*prints register value
	BRA		return_printEA
printAddrReg:
	LEA		An,A1				*prints 'A'
	JSR		print
	JSR		printHex				*prints register value
	BRA		return_printEA	
*prints address register indirect mode to screen, register value stored in D4
printAddrRegInd:
	LEA		AnInd,A1				*prints '(A'
	JSR		print
	JSR		printHex				*prints register value
	LEA		LPar,A1				*prints ')'
	JSR		print
	BRA		return_printEA
*prints address register indirect post increment to screen, uses pringAddrRegInd
printAddrRegPostIncr:
	LEA		AnInd,A1				*prints '(A'
	JSR		print
	JSR		printHex				*prints register value
	LEA		LPar,A1				*prints ')'
	JSR		print
	LEA		Plus,A1				*prints '+'
	JSR		print
	BRA		return_printEA
*prints address register indirect pre decrement to screen, uses pringAddrRegInd
printAddrRegPreDecr:
	LEA		Minus,A1				*prints '-'
	JSR		print
	LEA		AnInd,A1				*prints '(A'
	JSR		print
	JSR		printHex				*prints register value
	LEA		LPar,A1				*prints ')'
	JSR		print
	BRA		return_printEA
*prints the absolute effective address
printAbsoluteAddr:
	CMP		#0,D4				*(xxx).W
	BEQ		printAbsoluteAddrWord
	CMP		#1,D4				*(xxx).L
	BEQ		printAbsoluteAddrLong
	CMP		#4,D4				*#<data>
	BEQ		printImmediateData	
	BRA		return_printEA
*prints absolute word address to screen, reads next word in memory
printAbsoluteAddrWord:
	LEA		Hex,A1
	JSR		print
	MOVE.W	(A0)+,D1
	JSR		printHex
	BRA		return_printEA
*prints absolute long address to screen, reads next 2 words in memory
printAbsoluteAddrLong:
	LEA		Hex,A1
	JSR		print
	MOVE.W	(A0)+,D1
	JSR		printHex
	MOVE.W	(A0)+,D1
	JSR		printHex
	BRA		return_printEA
*prints immediate data to screen
printImmediateData:
	LEA		Hex,A1
	JSR		print
	MOVE.W	(A0)+,D1
	JSR		printHex
	MOVE.B	$30,D2
	CMP		#2,D2
	BLT		wd
	MOVE.W	(A0)+,D1
	JSR		printHex
wd	BRA		return_printEA
*branches to subroutine that prints the size following a label, size in D2
printSize:
	CMP		#0,D2				*.B
	BEQ		printByte
	CMP		#1,D2				*.W
	BEQ		printWord
	CMP		#2,D2				*.L
	BEQ		printLong
return_printSize
	RTS
*prints byte addressing mode to screen
printByte:
	LEA		Byte,A1				
	JSR		print
	BRA		return_printSize		
*prints word addressing mode to screen
printWord:
	LEA		Word,A1
	JSR		print
	BRA		return_printSize
*prints long addressing mode to screen	
printLong:
	LEA		Long,A1
	JSR		print
	BRA		return_printSize
*prints A for MOVEA
printA:
	CLR		D6
	MOVE.B	$40,D6
	CMP		#1,D6
	BNE		skp		
	LEA		An,A1
	JSR		print
skp	MOVE.B	#0,$40
	RTS	
**************************************************
*============= User Input Subroutines ============ 
**************************************************
*clears data registers from D0-D6
clearRegisters:
	CLR.L	D0
	CLR.L	D1
	CLR.L	D2
	CLR.L	D3
	CLR.L	D4
	CLR.L	D5
	CLR.L	D6
	RTS
*---Check subroutines---
chk8_D1:
	CMP		#0,D1				*checks length between [1,8]
	BEQ		ERR
	CMP		#8,D1
	BGT		ERR
	RTS
chkOdd_D2:
	MOVE.L	D2,D1				*checks if odd
	LSR.L	#1,D1
	BCS		ERR
	RTS
chkMax_D2:
	CMP.L	#$FFF0,D2			*checks if < $FFF0
	BGT		ERR
	RTS	
*used to check if start location is valid
chkStart:
	MOVEA.L #$00,A0				*convert A0 data to ascii in D2
	JSR		convertAscii_A0
	JSR		chk8_D1				
	JSR		chkMax_D2
	JSR		chkOdd_D2
	MOVE.L	D2,$00				*saves start long at $00	
	JSR		clearScreen
	BRA		inputEnd
*checks if end location valid
chkEnd:
	MOVEA.L #$10,A0				*convert A0 data to ascii in D2
	JSR		convertAscii_A0
	JSR		chk8_D1
	JSR		chkMax_D2
	JSR		chkOdd_D2
	MOVE.L	D2,$10				*saves start long at $10
	JSR		clearScreen
	BRA		afterInput
*converts contents of A0 to hex into D2, length in D1
convertAscii_A0:	
	MOVE.L	#0,D0
	MOVE.L	#0,D3				*D3 = counter
L0	MOVE.B	(A0)+,D0			*move A0 data to D0
	JSR		asciiToHex_D0		*change ascii char in D0
	CMP		#1,D5
	BEQ		ERR
	LSL.L	#4,D2				*shift D2
	ADD.B	D0,D2				*adds hex digit to rightmost
	ADD		#1,D3				*update counter
	CMP		D1,D3
	BLT		L0
	RTS
*converts ascii code in D0 to hexadecimal value
asciiToHex_D0:
	MOVE.B	#0,D5           
    CMP.B   #$66,D0    			*if(66 <  D1) invalid input
    BGT     ascii2Hex_err
    CMP.B   #$61,D0     		*if(61 <= D1 <= 66) a-f
    BGE     ascii_lower
    CMP.B   #$46,D0     		*if(46 <  D1 <  61) invalid input
    BGT     ascii2Hex_err
    CMP.B   #$40,D0     		*if(41 <= D1 <= 46) A-F
    BGE     ascii_upper  
    CMP.B   #$39,D0     		*if(39 <  D1 <  41) invalid input
    BGT     ascii2Hex_err
    CMP.B   #$30,D0     		*if(30 <  D1 <= 39) 0-9
    BGE     ascii_digits   
    CMP.B   #$30,D0     		*if(D1 <  30) invalid input
    BLT     ascii2Hex_err
ascii_lower  
    SUB.B   #$57,D0     		*ascii - 57 = lowercase a-fs
    BRA     RTS_a2H
ascii_upper  
    SUB.B   #$37,D0     		*ascii - 37 = uppercase A-F
    BRA     RTS_a2H
ascii_digits
    SUB.B   #$30,D0     		*ascii - 30 = digits 0-9
    BRA     RTS_a2H
ascii2Hex_err
	MOVE.B	#1,D5
RTS_a2H
	RTS
**************************************************
* General I/O subroutines
**************************************************
stringInput_iD2:
	MOVEA.L	D2,A1				*set A1 to target address in D2
	MOVE.B	#2,D0
	TRAP	#15
	RTS
waitForEnter:	
	CLR.L	D0
	MOVE.B  #5,D0				*Reads 1 char from keyboard
    TRAP    #15         
    CMP.B   #13,D1				*if(D1 == 13) return key typed
    RTS
*prints whatever is in A1 to screen
print:
	MOVE.L	#14,D0
	TRAP	#15
	RTS
*prints the hexadecimal number in D1
printHex:
	MOVE.B	#15,D0
	MOVE.B	#16,D2
	TRAP	#15
	RTS
*prints a new line
printNL:
	LEA		NL,A1
	JSR		print
	RTS
*prints a tab
printTAB:
	LEA		TB,A1
	JSR		print
	RTS
*prints a comma
printCMA:
	LEA		CMA,A1
	JSR		print
	RTS
*blanks out the console
clearScreen:
	MOVE.L	#11,D0				
	MOVE.L	#$ff00,D1
	TRAP	#15
	RTS		
*counts the number of lines currently on the screen
lineCount:
	CMP.W	#$1C,($20)			*prints up to 18 lines
	BGE		stopScreen
	ADD.W	#1,$20				*increment line counter
	RTS
*interrupts output and waits for user input of esc/return
stopScreen:
	MOVE.L	#0,$20				*resets counter
	LEA		Stop,A1				*prompts to hit enter/esc
	JSR		print
	CLR.L	D0
	MOVE.B  #5,D0				*Reads 1 char from keyboard
    TRAP    #15         
    CMP.B   #27,D1				*escape key typed
    BEQ     inputAgain
    CMP.B   #13,D1				*return key typed
    BEQ     continue
    BRA		stopScreen
continue	
	RTS
*prints message that program is ending
endProgram:
	JSR		printNL
	LEA		ExitMsg,A1
	JSR		print
	BRA		DONE
**************************************************
* User Input Error subroutines
**************************************************
*branches to correct input error subroutine
ERR:
	CMP		#0,D6
	BEQ		ERR0
	BRA		ERR1
*error with start input value, restarts input
ERR0:
	LEA		ErrMsg0,A1
	JSR		print
	JSR		clearRegisters
	JSR		waitForEnter
	JSR		clearScreen
	BRA		inputStart
*error with end input value, restarts input
ERR1:
	LEA		ErrMsg0,A1
	JSR		print
	JSR		clearRegisters
	MOVE.L	#0,$10
	JSR		waitForEnter
	JSR		clearScreen
	BRA		inputEnd
*--------------------------Constants------------------------
*messages
Prmpt0	DC.B	'Enter the starting location:',CR,LF,0
Prmpt1	DC.B	'Enter the ending location:',CR,LF,0
Prmpt2	DC.B	'Disassemble another memory location? [Y/n] ',0
ErrMsg0 DC.B	'Invalid entry, hit enter to try again.',CR,LF,0
Stop	DC.B	CR,LF,'[[ Hit enter to continue, esc to exit ]]',CR,LF,0
ExitMsg	DC.B	'Program terminated.',CR,LF,0
*opcode labels
UK		DC.B	'DATA    $',0
OpMOVE  DC.B    'MOVE',0
OpNOP   DC.B    'NOP',CR,LF,0
OpRts   DC.B    'RTS',CR,LF,0
OpClr   DC.B    'CLR',0
OpLEA   DC.B    'LEA',0
*addressing modes
Byte	DC.B	'.B',0
Word	DC.B	'.W',0
Long	DC.B	'.L',0
Dn		DC.B	'D',0
An		DC.B	'A',0
AnInd   DC.B	'(A',0
LPar	DC.B	')',0
Plus	DC.B	'+',0
Minus	DC.B	'-',0
Hex		DC.B	H,0
Cma		DC.B	C,0
TB		DC.B	T,0
SP1		DC.B	S,0
SP2		DC.B	S,S,0
SP3		DC.B	S,S,S,0
*characters
NL		DC.B	CR,LF,0
CR      EQU     $0D
LF      EQU     $0A
T		EQU		$09
H		EQU		$24
C		EQU		$2C
S		EQU		$20
*------------------------End of Program---------------------
DONE:	
	MOVE.B	#9,D0			*Halt simulator
    END    	START			*End program







*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
