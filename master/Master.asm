;***********************************************************************************************************************************************************************
;															MASTER
; 															1Mbit/s
;  Osc a 16Mhz
;  Il programma caricato sul pic master deve gestire le comunicazioni da e verso l FPGA e lo Slave,utilizzando rispettivamente i protocolli
;  Seriale e CAN. Potrà ricevere un aggiornamento delle ricette dall FPGA, che verranno caricate in variabili temporanee. Ci sono comunque alcune
;  ricette di default in memoria nel master. A queste è associato un codice che proviene dall FPGA e 4 cifre che saranno inviate allo slave, utilizzate come contatori.
;  Il master dovrà anche ricevere aggiornamenti dallo slave sullo stato dei galleggianti. Quando i serbatoi sono vuoti viene mandato un messaggio alert all FPGA
;  e non sarà inviata alcuna ricetta allo slave
;***********************************************************************************************************************************************************************

	processor	PIC18F458
	
	include		"p18f458.inc"

	CBLOCK	0x60
	flag;useremo questi 8 bit come flag da utilizzare nel programma
	IDH
	temp_d0
	temp_dlc
	IDL
	message; in questa variabile andiamo a memorizzare i dati ricevuti via usart
	DLC
	cont
	temp_sidh
	temp_sidl
	cont1
	cont2
	DATO
	DATO1
	DATO2
	DATO3
	orange;variabili in cui memorizziamo i valori dei relativi contatori che andranno comunicati allo slave via CAN
	lemon;
	vodka;
	vodka_p;
	msg_usart ;variabile di appoggio per l'invio di messaggi via USART
	ENDC

	ORG	0x00
	nop
	goto START

	ORG 0x08
	banksel INTCON
	bcf INTCON,7;Disabilito gli interrupt generali
	nop
	btfsc PIR3,0; testo se il buffer0 è pieno che ci indicherebbe che è stato ricevuto un messaggio via can
	goto CAN
	btfsc PIR1,5; testo se il registro usart di ricezione è pieno che ci indicherebbe che è stato ricevuto un messaggio via usart
	goto USART

	nop	;in teoria qua non ci andremo mai, ma lo mettiamo per sicurezza da errori
	nop
	banksel INTCON;riabilitiamo gli interrupt generali
	bsf INTCON,7
	retfie

CAN;galleggianti bad news
	call RECEIVE

	banksel PIR3 ;azzero il flag di interrupt buffer 0
	bcf PIR3,0
	banksel INTCON;riabilitiamo gli interrupt generali
	bsf INTCON,7
	retfie


USART

	call USART_R
	nop

	nop
	movlw B'00001111'
	banksel message
	andwf message,W
	movwf message
	nop ;test per vedere quale ricetta è stata richiesta dalla FPGA per poi inviarla via CAN allo slave

	;controllo quale codice ricetta ho ricevuto nel messaggio e richiamo laricetta corrispondente


;fin qua ci arriva

	movlw B'00000001' ;ricetta 1
	CPFSEQ message
	goto comp2
	call receipt1

comp2
;fin qua ci arriva
	movlw B'00000010' ;ricetta 2
	nop
	CPFSEQ message
	goto comp3
	call receipt2

comp3
; fin qua ci arriva
	movlw B'00000011' ;ricetta 3
	nop
	CPFSEQ message
	goto comp4
	call receipt3

comp4

	movlw B'00000100' ;ricetta 4
	nop
	CPFSEQ message
	goto comp5
	call receipt4

comp5

	movlw B'00000101' ;ricetta 5
	nop
	CPFSEQ message
	goto comp6
	call receipt5

comp6

	movlw B'00000110' ;ricetta 6
	nop
	CPFSEQ message
	goto comp7
	call receipt6

comp7

	movlw B'00000111' ;ricetta 7
	nop
	CPFSEQ message
	goto comp8
	call receipt7

comp8

	movlw B'00001000' ;ricetta 8
	nop
	CPFSEQ message
	goto comp9
	call receipt8

comp9

	movlw B'00001001' ;ricetta 9
	nop
	CPFSEQ message
	goto comp10
	call receipt9

comp10
	
	movlw B'00001010' ;ricetta 10
	nop
	CPFSEQ message
	goto end_comp
	call receipt10

end_comp

	bsf PORTB,0;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;metto qua l accensione del led per vedere se di qui ci passa...per ora no
;;;;;;;;;;;;;

	movlw	B'00001000' ;Identificativo parte alta
	banksel	IDH	
	movwf	IDH
	
	movlw	B'00100000' ;ultimi tre bit dell'identificativo
	banksel	IDL
	movwf	IDL
	
	movlw	B'00000100'	;Invio 4 byte
	banksel	DLC
	movwf	DLC
	;TXRTR    è il bit che bisogna settare se si vuole ricevere una risposta una volta inviato il dato....mettendolo a 0 gli si dice che non vogliamo una risposta.

	banksel DATO
	movff orange, DATO
	movff vodka_p, DATO1
	movff lemon, DATO2
	movff vodka, DATO3



	call invio_msg
	nop


	call wait_answer
	nop

	call RECEIVE	;qui ci andrebbe un controllo per vedere se il messaggio ricevuto  quello di fine erogazione

	;a questo punto si manda il messaggiodi erogazione terminata via usart alla FPGA

	movlw 'F' ;F indica la fine dell'erogazione
	banksel msg_usart
	movwf msg_usart
	call send_usart
	nop
	
no_Rec
	nop
	nop
	banksel PIR1
	bcf PIR1,5 ;azzeriamo il flag di interrupt da usart
	banksel INTCON;riabilitiamo gli interrupt generali
	bsf INTCON,7
	retfie
	
	
	
START
	banksel WDTCON
	clrf	WDTCON
;Questo disabilita il watchdog timer

;-----------------------------------------------------------------------------------------------
;                               INIZIALIZZAZIONE DELLA PORT B
;-----------------------------------------------------------------------------------------------


	banksel TRISB		;mi sposto nel bank dove c'e' TRISB
	movlw B'11111010'	;linea RB3 CAN_RX = 1 INPUT,
	movwf TRISB			;linea RB2 CAN_TX = 0 OUTPUT
	;(le linee non utilizzate sono a 1 =IN)

	banksel PORTB		;vado nel bank dove c'e' PORTB
	clrf PORTB			;e azzero tutto
			
;---------------------------------------------------------------------------------------------
;                              INIZIALIZZAZIONE DELLA PORT E
;---------------------------------------------------------------------------------------------
 
	banksel TRISE
	clrf TRISE		

	banksel PORTE	;vado nel bank dove c'e' PORTE
	clrf PORTE			;e azzero tutto
;abbiamo messo la porte come outoput perchè, prima di entrare nel main, accenderemo 
;un led sulla port1 di funzionamento

;-----------------------------------------------------------------------------------------------
;                               INIZIALIZZAZIONE DELLA PORT C
;-----------------------------------------------------------------------------------------------

	banksel TRISC		;mi sposto nel bank dove c'e' TRISB
	movlw B'10111111'	;linea RC7 USART_RX = 1 INPUT,
	movwf TRISC			;linea RC6 USART_TX = 0 OUTPUT
	;(le linee non utilizzate sono a 1 =IN)

	banksel PORTC		;vado nel bank dove c'e' PORTC
	clrf PORTC			;e azzero tutto

;---------------------------------------------------------------------------------------------
;	                ABILITAZIONE DEGLI INTERRUPT DOVUTI A:
;
;	                 - buffer0 di ricezione del modulo CAN
;               	 - buffer1 di ricezione del modulo CAN
;
;---------------------------------------------------------------------------------------------
;	IN QUESTO CASO NON UTILIZZIAMO GLI INTERRUPT
	
	banksel RCON
	movlw B'00000000'
	movwf RCON		;disabilito interrupt priorizzati

	banksel INTCON
	movlw B'00000000'
	movwf INTCON		;abilitazione generale interrupt (bit 7), 
						;abilitazione interrupt da periferiche (bit 6)

	banksel INTCON2
	movlw B'00000000'
	movwf INTCON2		

	banksel INTCON3
	movlw B'00000000'
	movwf INTCON3		

	banksel PIR1		;azzero tutti i flag di tutti gli interrupt
	movlw B'00000000'
	movwf PIR1

	banksel PIR2
	movlw B'00000000'
	movwf PIR2

	banksel PIR3
	movlw B'00000000'
	movwf PIR3

	banksel PIE1		;disabilito tutti gli interrupt relativi a questo registro in particolare a quello dell usart che attiveremo al momento opportuno
	movlw B'00000000'
	movwf PIE1

	banksel PIE2
	movlw B'00000000'	;disabilito tutti gli interrupt relativi a questo registro
	movwf PIE2

	banksel PIE3		;disabilito gli interrupt del PIE3, in particolare quello del CAN che attiveremo al momento opportuno
	movlw B'00000000'
	movwf PIE3

;----------------------------------------------------------------------------------------------
;	                        CONFIGURAZIONE MODULO CAN
;----------------------------------------------------------------------------------------------
	
	banksel CANCON
	movlw B'10000000'			;SETTO IL MODULO CAN IN CONFIGURATION MODE 
	movwf CANCON


	banksel	CANSTAT

CONFIGMODE
	
	btfss 	CANSTAT,7	;TESTO IL BIT OPMODE2 DEL CANSTAT PER VEDERE VEDERE SE SONO GIA IN CONFIGURATION MODE
	goto 	CONFIGMODE

;-----------------------BAUDRATE----------------------------------------------------------

	;Baud rate 1Mbit/s

	banksel	BRGCON1  	;SETTO SYNCRO JUMP WIDTH di 1Tq E BAUD RATE PRESCALER = 1
						;Tq=(2x1)/Fosc = 0.125uS
	movlw	B'00000000' 
	movwf	BRGCON1
	
	banksel	BRGCON2
	movlw	B'10010000'  	;SETTO PHASE SEG2 TIME  liberamente programmabile,
							;SAM campiono una volta sola, PHASE SEG1 = 3 Tq, PROPAGATION TIME = 1Tq
	movwf	BRGCON2
	
	banksel	BRGCON3
	movlw	B'00000010'  	;SETTO WAKFIL niente wake-up dal bus, PHASE SEG2 TIME =3Tq
	movwf	BRGCON3

;------------------------registri RX--------------------------------------------------------------

;------------------------BUFFER 0---------------------------------------------------------
;ANDIAMO A CONFIGURARE I DUE FILTRI IN RICEZIONE 0 E 1 CHE POSSONO ESSERE GESTITI ENTRAMBI DAL BUFFER 0.
;IN QUESTO MODO USEREMO IN RICEZIONE SOLAMENTE IL BUFFER 0 E, UNA VOLTA ENTRATO NELL'INTERRUPT, FAREMO UN CHECK PER 
;CAPIRE QUALI DEI DUE FILTRI E' STATO "COLPITO".
	banksel	RXB0CON
	movlw	B'00100000'  	;configuro il buffer 0 di ricezione
	movwf	RXB0CON

	banksel	RXF0SIDH		;filtro 0 riceve PWM=00001/000100
	movlw	B'00001000'   	;configuro i primi 8 bit del filtro 0
	movwf	RXF0SIDH
	
	banksel	RXF0SIDL
	movlw	B'10000000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF0SIDL		;filtro per messaggio fine erogazione

	banksel	RXF1SIDH		;filtro 1 riceve richiesta Tatt=00001/000101
	movlw	B'00001000'   	;configuro i primi 8 bit del filtro 1
	movwf	RXF1SIDH
	
	banksel	RXF1SIDL
	movlw	B'10100000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF1SIDL		;filtro per messaggio risposta livelli
	
	banksel	RXM0SIDH
	movlw	B'11111111'   	;configuro i primi 8 bit della maschera 0
	movwf	RXM0SIDH
	
	banksel	RXM0SIDL
	movlw	B'11100000'   	;configuro i restanti 3 bit della maschera==> se il messaggio non è perfetto non passa
	movwf	RXM0SIDL
	
;---------------------------------------------------------------------------	
;													BUFFER 1 
	
	banksel	RXB1CON
	movlw	B'00100000'  	;configuro il buffer 1 di ricezione
	movwf	RXB1CON

	banksel	RXF2SIDH		;filtro 2 riceve richiesta Tmax=00001/000011
	movlw	B'00001000' 	;configuro i primi 8 bit del filtro 2
	movwf	RXF2SIDH
	
	banksel	RXF2SIDL
	movlw	B'01100000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF2SIDL

	banksel	RXF3SIDH		;filtro 3 riceve richiesta Tmin=00001/000100
	movlw	B'00001000' 	;configuro i primi 8 bit del filtro 3
	movwf	RXF3SIDH
	
	banksel	RXF3SIDL
	movlw	B'10000000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF3SIDL
	
	banksel	RXF4SIDH		;filtro 4 riceve xxxxxxxxx=00001/000101
	movlw	B'00001000' 	;configuro i primi 8 bit del filtro 4
	movwf	RXF4SIDH

	banksel	RXF4SIDL
	movlw	B'10100000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF4SIDL

	banksel	RXF5SIDH		;filtro 5 riceve nuova Tall=00001/000000
	movlw	B'00001000' 	;configuro i primi 8 bit del filtro 5
	movwf	RXF5SIDH
	
	banksel	RXF5SIDL
	movlw	B'00000000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages
	movwf	RXF5SIDL
	
	banksel	RXM1SIDH
	movlw	B'11111111'   	;configuro i primi 8 bit della maschera 1
	movwf	RXM1SIDH
	
	banksel	RXM1SIDL
	movlw	B'11100000'  	;configuro i restanti 3 bit della maschera==> se il messaggio non è perfetto non passa
	movwf	RXM1SIDL
	
;------------------------------------------------------------------------------------	
;											REGISTRI TX	
;------------------------------------------------------------------------------------	
	
	
	banksel	TXB0CON
	movlw	B'00000000'  	;configuro il registro TXB0CON
	movwf	TXB0CON

;--------------------------------------------------------------------------------------------	
;									esco dal configuration mode	
	
	banksel	CANCON
	movlw	B'00000000'  	;attivo il modulo CAN in normal mode-----receive buffer 0
	movwf	CANCON

	banksel CANSTAT

NORMALMODE

	btfsc 	CANSTAT,OPMODE2	;questi cicli servono per verificare di essere tornati in normal mode
	goto 	NORMALMODE

	btfsc 	CANSTAT,OPMODE1	
	goto 	NORMALMODE

	btfsc 	CANSTAT,OPMODE0	
	goto 	NORMALMODE

	clrf flag; inizializzato a 0 la variabile flag

;************************************************************************************************
;                                   	INIZIALIZZAZIONE USART
;************************************************************************************************
;ora mettiamo il baud rate a 9600 bps. Facendo i conti ci viene che abbiamo un errore di circa 1.9 bps. E' abbastanza poco, il 0.016 %
	banksel SPBRG
	movlw D'103'
	movwf SPBRG

	banksel TXSTA

	clrf TXSTA

	bcf TXSTA,7;non ci interessa perchè è per la sincro
	bcf TXSTA,6; 8 bit
	bsf TXSTA,5; enable
	bcf TXSTA,4; scegliamo sincrona
	bcf TXSTA,3;non ci int
	bsf TXSTA,2;high speed baud rate
	bcf TXSTA,1; non ci interessa è per la lettura
	bcf TXSTA,0;è per il nono bit che non abbiamo


	banksel RCSTA

	clrf RCSTA

	bsf RCSTA,7;enable
	bcf RCSTA,6;8bit
	bcf RCSTA,5;non ci int
	bsf RCSTA,4; abilitiamo la ricezione continua
	bcf RCSTA,3;non ci int
	bcf RCSTA,2;sono errori lasciamo stare
	bcf RCSTA,1;sono errori lasciamo stare
	bcf RCSTA,0;;è per il nono bit che non abbiamo
	

INITIALIZE_RECEPIT ;inizializzazione delle variabili da utilizzare nel programma
	banksel message
	clrf message
	banksel orange
	clrf orange
	banksel vodka
	clrf vodka
	banksel vodka_p
	clrf vodka_p
	banksel lemon
	clrf lemon

INITIALIZE_RECEIPT_RS; qua metteremo l'aggiornamento delle ricette via RS232, se avremo tempo e modo. Ora lo lasciamo vuoto.
	nop

;Accendo il led di funzionamento del pic
	banksel PORTE
	bsf	PORTE,1

;************************************************************************************************
;                                   PROGRAMMA PRINCIPALE
;************************************************************************************************


CHECK_STATE_SLAVE
	nop
	nop
;qua mettiamo il comando , ora solo come commento, di test sul bit 1 del flag, che alziamo dal momento che entriamo in check_state_slave
; se entriamo li vuol dire che qualcosa è stato ricevuto dallo slave, ma, siccome siamo tornati in questo ciclo, vuol dire che i galleggianti non sono ok
; quindi chiameremo la routine di comunicazione con l fpga, denominata provvisorimente USART_AFLOAT_OFF

	;btfsc flag,1
	;call USART_AFLOAT_OFF

	nop
	btfss RXB0CON,RXFUL
	goto CHECK_STATE_SLAVE
	nop
	call test_answer1
	nop
	btfss flag,0; testiamo il flag inizializzato precedentemente. Se è alzato, allora noi possiamo mandare le ricette, altrimenti vuol dire che i galleggianti non sono a posto e 
; quindi aspettiamo che vengano messi a posto.
	goto CHECK_STATE_SLAVE
	nop
	nop
	
	;abilito gli interrupt ora in modo da evitare problemi di interrupt invio messaggi FPGA
	
	banksel PIE3;setto interrupt per buffer 0 e 1 pieno
	bsf PIE3,1
	bsf PIE3,0
	banksel INTCON; abilito gli interrupt generali

	;AZZERO il flag dell interrupt della ricezione usart
	banksel PIR1
	bcf PIR1,RCIF

;abilito gli interrupt in ricezione usart
	banksel PIE1
	bsf PIE1, RCIE
	
;abilito gli iterrupt generali
	bsf INTCON,7
	bsf INTCON,6
	nop
	
	;invio alla FPGA un messaggio di livelli ok

	movlw 'L' ;L indica livelli ok
	banksel msg_usart
	movwf msg_usart
	call send_usart	
	nop
	
MAIN
	nop
	nop
	nop
    banksel flag
    btfss flag,0
    goto CHECK_STATE_SLAVE
    nop
	goto MAIN

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------
;																	RICETTE MEMORIZZATE
;---------------------------------------------------------------------------------------------------------------------------------------------------------------------

receipt1;VODKA LISCIA (DA BERE ALL'ALPINA)
	banksel orange
	movlw B'00000000'
	movwf orange

	banksel vodka_p
	movlw B'00000000'
	movwf vodka_p

	banksel lemon
	movlw B'00000000'
	movwf lemon

	banksel vodka
	movlw B'00001100';12
	movwf vodka
	return
	
receipt2;VODKA ORANGE
	banksel orange
	movlw B'00010100';20
	movwf orange

	banksel vodka_p
	movlw B'00000000'
	movwf vodka_p

	banksel lemon
	movlw B'00000000'
	movwf lemon

	banksel vodka
	movlw B'00001011';11
	movwf vodka
	return

receipt3;VODKA LEMON
	banksel orange
	movlw B'00000000'
	movwf orange

	banksel vodka_p
	movlw B'00000000'
	movwf vodka_p

	banksel lemon
	movlw B'00010100';20
	movwf lemon

	banksel vodka
	movlw B'00001011';11
	movwf vodka
	return

receipt4;PESQUITO
	banksel orange
	movlw B'00000000'
	movwf orange

	banksel vodka_p
	movlw B'00001111';15
	movwf vodka_p

	banksel lemon
	movlw B'000010101';21
	movwf lemon

	banksel vodka
	movlw B'00000000'
	movwf vodka
	return

receipt5;VODKA PESCA LISCIA
	banksel orange
	movlw B'00000000'
	movwf orange

	banksel vodka_p
	movlw B'00001111';15
	movwf vodka_p

	banksel lemon
	movlw B'00000000'
	movwf lemon

	banksel vodka
	movlw B'00000000'
	movwf vodka
	return

receipt6;ARANCIATA
	banksel orange
	movlw B'00010111';23
	movwf orange

	banksel vodka_p
	movlw B'00000000'
	movwf vodka_p

	banksel lemon
	movlw B'00000000'
	movwf lemon

	banksel vodka
	movlw B'00000000'
	movwf vodka
	return

receipt7;SEX ON THE BEACH (MAGARI)
	banksel orange
	movlw B'00001111';15
	movwf orange

	banksel vodka_p
	movlw B'00001100';12
	movwf vodka_p

	banksel lemon
	movlw B'00000000'
	movwf lemon

	banksel vodka
	movlw B'00001000';8
	movwf vodka
	return

receipt8;limonata
	banksel orange
	movlw B'00000000'
	movwf orange

	banksel vodka_p
	movlw B'00000000'
	movwf vodka_p

	banksel lemon
	movlw B'00010101';21
	movwf lemon

	banksel vodka
	movlw B'00000000'
	movwf vodka
	return

receipt9;MAD (MIX AND DRINK)
	banksel orange
	movlw B'00001000';8
	movwf orange

	banksel vodka_p
	movlw B'00001000';8
	movwf vodka_p

	banksel lemon
	movlw B'00001000';8
	movwf lemon

	banksel vodka
	movlw B'00001000';8
	movwf vodka
	return

receipt10;MOSCOW
	banksel orange
	movlw B'00000000'
	movwf orange

	banksel vodka_p
	movlw B'00001010';10
	movwf vodka_p

	banksel lemon
	movlw B'00000000'
	movwf lemon

	banksel vodka
	movlw B'00001010';10
	movwf vodka
	return

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------
;																FINE RICETTE MEMORIZZATE
;---------------------------------------------------------------------------------------------------------------------------------------------------------------------


;																	INIZIO ROUTINE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;																	ROUTINE DI DELAY

DELAY
	nop
	banksel cont2

dlyloop
	decfsz cont, F
	goto dlyloop

	decfsz cont1,F
	goto dlyloop

	decfsz cont2,F
	goto dlyloop
	nop
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;---------------------------------------------------------------------------------------------------
;
;                                       CALL	INVIO	MESSAGGIO	CAN
;
;----------------------------------------------------------------------------------------------------

invio_msg
	nop
	nop

	banksel	IDH
	movf	IDH,W
	banksel	TXB0SIDH
	movwf	TXB0SIDH
		
	banksel	IDL
	movf	IDL,W
	banksel	TXB0SIDL
	movwf	TXB0SIDL		

	banksel	DLC
	movf	DLC,W
	banksel	TXB0DLC
	movwf	TXB0DLC

	banksel	DATO
	movf	DATO,W
	banksel	TXB0D0
	movwf	TXB0D0
;metto il dato che voglio trasmettere nel bit 0 del registro di trasmissione 0.

	banksel	DATO1
	movf	DATO1,W
	banksel	TXB0D1
	movwf	TXB0D1

	banksel	DATO2
	movf	DATO2,W
	banksel	TXB0D2
	movwf	TXB0D2

	banksel	DATO3
	movf	DATO3,W
	banksel	TXB0D3
	movwf	TXB0D3



	banksel TXB0CON	
	bsf		TXB0CON,TXREQ
	nop

invia	
	nop
	btfss	TXB0CON,TXREQ
	goto	trasmissione_positiva

	btfsc	TXB0CON,TXERR
	goto	aborto

	btfsc	TXB0CON,TXLARB
	goto	aborto
	
	btfsc	TXB0CON,TXABT
	goto	aborto
	
	goto	invia
	
aborto	
	bcf		TXB0CON,TXREQ
	goto	invio_msg
		
trasmissione_positiva		
	
	return

;----------------------------------------------------------------------------------------		
;			Call wait_answer
;----------------------------------------------------------------------------------------

wait_answer
	nop
	nop
	banksel RXB0CON
	btfss RXB0CON,RXFUL ;controllo il bit flag di riempimento buffer 0
	goto wait_answer
	nop
	nop
	banksel RXB0CON
	bcf RXB0CON, RXFUL ;reset bit flag buffer 0
	nop
	nop
	nop
	return


;----------------------------------------------------------------------------------------
;			Call test_answer1
;----------------------------------------------------------------------------------------

test_answer1

;qui ci andrebbero i controlli ai bit FILHIT dei RXBnCON

	;banksel flag
	;bsf flag,1
	; questi due comandi per ora commentati ci servono, una volta usciti, per poter eventualmente comunicare all fpga che i livelli dei galleggianti non sono ok


	banksel RXB0SIDH
	movff RXB0SIDH, temp_sidh

	banksel RXB0SIDL
	movff RXB0SIDL, temp_sidl
	
	banksel RXB0DLC
	movff RXB0DLC, temp_dlc

	;copio il dato ricevuto
	banksel RXB0D0
	movff RXB0D0, temp_d0

	banksel RXB0CON
	bcf RXB0CON,7; azzero il flag che mi indica che il buffer 0 è pieno. 
				 ;così possiamo attendere un altro messaggio ne caso in cui i galleggianti non siano ancora ok

	btfss temp_sidl,5 ;testiamo se ilmessaggio ricevuto ha l'identificativo del messagio risposta livelli. Se non è lui torno al CHECK_STATE_SLAVE
	return
	nop
	TSTFSZ temp_d0 ;Se il mesaggio rievuto è composto solo da zeri allora tutti i serbatoi sono pieni ed è possibile possibile passare allo stato Wait_Drink 
	return
	bsf flag,0;settiamo il bit 0 della variabile flag alto, faremo poi un check nell'interrupt per vedere se si può trasmettere o meno la ricetta
	nop
	nop
	return
;--------------------------------------------------------------------------------------------------------------------------------------------------------------------
;																RICEZIONE CAN
;--------------------------------------------------------------------------------------------------------------------------------------------------------------------
RECEIVE
	;copio gli identificativi del buffer 0 in variabili temporanee

	banksel RXB0SIDH
	movff RXB0SIDH, temp_sidh

	banksel RXB0SIDL
	movff RXB0SIDL, temp_sidl
	
	;copio dato lunghezza messaggio
	; in questo registro gli ultimi quattro bit mi dicono quanti byte sono stati ricevuti
	banksel RXB0DLC
	movff RXB0DLC, temp_dlc

	;copio il dato ricevuto dal registro di ricezione del buffer 0
	banksel RXB0D0
	movff RXB0D0, temp_d0
	nop
	nop
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;																	RICEZIONE USART

USART_R

;Qua controlliamo se ci sono stati degli errori durante la ricezione, se ci sono stati mandiamo il programma all'istruzione errror_usart
	btfsc RCSTA,2
	goto Error_Usart
	btfsc RCSTA,1
	goto Error_Usart
	
	banksel message
	
	movff RCREG, message
	;movf RCREG,W
;mettiamo il contenuto di ciò che è stato ricevuto nel working register nella variabile "message"
	;movwf message

	return

Error_Usart
	
	movlw 'E'
	banksel msg_usart
	movwf msg_usart
	call send_usart
	clrf message
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;																		TRASMISSIONE USART

send_usart
	banksel msg_usart ;variabile di appoggio per inviare messaggi via usart
	movf msg_usart, W
	banksel TXREG
	movwf TXREG
	banksel TXSTA
TX_E btfss TXSTA, TRMT
	goto TX_E
	nop
	return
	end	