;***********************************************************************************************
; 												SLAVE
; 												1Mbit/s
;  Osc A 16Mhz  
; Il programma deve gestire 4 elettrovalvole e 4 galleggianti e comunciare con il master
;***********************************************************************************************
	processor	PIC18F458

	include		"p18f458.inc"

	CBLOCK	0x60
	DATO;variabile temp. per invio dati
	IDH;variabile temp. per identificativo alto
	IDL;variabile temp. per identificativo basso
	DLC;variabile temp. per lunghezza messaggio
	temp_sidh;variabile temp. per memorizzare identificativo alto in ricezione
	temp_sidl;variabile temp. per memorizzare identificativo basso in ricezione
	temp_dlc;variabile temp. per memorizzare lunghezza messaggio in ricezione
	cont; variabile per contatore
	cont1; variabile per contatore
	cont2; variabile per contatore
	temp_d0; variabile temp di memorizzazione dati ricevuti
	temp_d1; variabile temp di memorizzazione dati ricevuti
	temp_d2; variabile temp di memorizzazione dati ricevuti
	temp_d3; variabile temp di memorizzazione dati ricevuti
	valve_cont1;variabile per contatore serbatoio 1
	valve_cont2;variabile per contatore serbatoio 2
	valve_cont3;variabile per contatore serbatoio 3
	valve_cont4;variabile per contatore serbatoio 4
	Levels;variabile temporanea per confronto livelli galleggianti su più acquisizioni
	Levels2;variabile temporanea per confronto livelli galleggianti su più acquisizioni
	Levels3;variabile temporanea per confronto livelli galleggianti su più acquisizioni
	flag; variabile di flag vari che possono essere utilizzati durante il programma. Il bit 0 è riferito all'avvenuta erogazione 
	PORTA_app
	PORTC_app
	PORTD_app
	ENDC

	ORG	0x00
	nop
	goto START

;-------------------------------------------------------------------------
;			Interrupt
;-------------------------------------------------------------------------

	ORG 0x08
	banksel INTCON
	bcf INTCON,7 ;disaibilito interrupt
	
	call RECEIVE
	nop
	nop
	banksel temp_d0; copio le variabili temporanee su cui abbiamo appoggiato i dati ricevuti nei contatori delle valvole
	movff temp_d0,valve_cont1
	nop
	nop
	banksel temp_d1
	movff temp_d1,valve_cont2
	nop
	nop
	banksel temp_d2
	movff temp_d2,valve_cont3
	nop
	nop
	banksel temp_d3
	movff temp_d3,valve_cont4
	nop
	nop
	nop	
	banksel PORTB
	bsf PORTB,0
	nop
	call Open_Valves
 
	nop
	nop

	banksel PORTB
	bcf PORTB,0


	banksel DATO
	movlw B'00000001'
	movwf DATO

	banksel IDH
	movlw B'00001000'
	movwf IDH

	banksel IDL
	movlw B'10000000'
	movwf IDL

	banksel DLC
	movlw B'00000001'
	movwf DLC
	nop
	nop
	call Answer_To_Master

	nop
	nop
	nop
Reset_interrupt
	;azzero il flag di buffer pieno a indicare che il dato è stato letto per cui il buffer può esere sovrascritto alla ricezione di nuovi dati
	banksel RXB0CON
	bcf RXB0CON, 7
	;Azzero il flag di interrupt buffer0 pieno
	banksel PIR3
	bcf PIR3,0


;Riabilito gli interrupt
	banksel INTCON
	bsf INTCON, GIE
	
	banksel flag		
	movlw B'00000001'	;disabilito tutti gli interrupt relativi a questo registro
	movwf flag
	;bsf flag,0; ora alziamo questo flag perchè in questo modo, rientrato nel main dopo il retfie qui sotto, verrà fatto un check su questo bit e verrà trasmesso
;al master il livello galleggiante. Se è ok, si torna subito nel main ad attendere una nuova ricetta, altrimenti si resta in wait refill
	retfie
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;											INIZIALIZZAZIONE DI TUTTI I PARAMETRI DELLA CAN E DELLO SLAVE
START

	banksel	WDTCON
	clrf	WDTCON
; Questo disabilita il watchdog timer

;-----------------------------------------------------------------------------------------------
;                               INIZIALIZZAZIONE DELLA PORT A
;-----------------------------------------------------------------------------------------------
	banksel TRISA		;mi sposto nel bank dove c'e' TRISA
	movlw B'00001111'
			;a queste porte andrò a collegare i galleggianti
	movwf TRISA	
						

	banksel PORTA		;vado nel bank dove c'e' PORTA
	bcf PORTA,0
	bcf PORTA,1
	bcf PORTA,2
	bcf PORTA,3				
							;e azzero tutto


;Disattivo il convertitore analogico/digitale
	banksel ADCON0
	clrf ADCON0
;settaggio PORTA come tutta digitale (la devo settare così altrimenti non riesco a leggere i valori dei galleggianti)
	banksel ADCON1
	movlw B'00000111'
	movwf ADCON1
;-----------------------------------------------------------------------------------------------
;                               INIZIALIZZAZIONE DELLA PORT B
;-----------------------------------------------------------------------------------------------
	banksel TRISB		;mi sposto nel bank dove c'e' TRISB
	movlw B'11111010'	;linea RB3 CAN_RX = 1 INPUT,
	movwf TRISB			;linea RB2 CAN_TX = 0 OUTPUT
						;linea RB0 viene impostata come un output...nel nostro programma di prova sarà un semplice led che si accende in caso di avvenuta ricezione

	banksel PORTB		;vado nel bank dove c'e' PORTB
	movlw B'00000000'
	movwf PORTB			;e azzero tutto

;---------------------------------------------------------------------------------------------
;                              INIZIALIZZAZIONE DELLA PORT E
;--------------------------------------------------------------------------------------------- 
	banksel TRISE
	clrf TRISE

	banksel PORTE		;vado nel bank dove c'e' PORTE
	clrf PORTE			;e azzero tutto
;---------------------------------------------------------------------------------------------
;                              INIZIALIZZAZIONE DELLA PORT C
;---------------------------------------------------------------------------------------------
	banksel TRISC
	clrf TRISC
	bcf TRISC,7
	bcf TRISC,4

	banksel PORTC		;vado nel bank dove c'e' PORC
	clrf PORTC			;e azzero tutto

;---------------------------------------------------------------------------------------------
;                              INIZIALIZZAZIONE DELLA PORT D
;---------------------------------------------------------------------------------------------
	banksel TRISD
	clrf TRISD
	bcf TRISD,3
	bcf TRISD,2

	banksel PORTD		;vado nel bank dove c'e' PORTD
	clrf PORTD			;e azzero tutto

;---------------------------------------------------------------------------------------------
;                              INIZIALIZZAZIONE DELLE VARIABILI
;---------------------------------------------------------------------------------------------

	banksel PORTC_app
	movlw B'00000000'

	banksel PORTD_app
	movlw B'00000000'

	banksel flag
	movlw B'00000000'
	movwf flag

	banksel temp_d0
	movlw B'00000000'
	movwf temp_d0

	banksel temp_d1
	movlw B'00000000'
	movwf temp_d1

	banksel temp_d2
	movlw B'00000000'
	movwf temp_d2

	banksel temp_d3
	movlw B'00000000'
	movwf temp_d3

	banksel valve_cont1
	movlw B'00000000'
	movwf valve_cont1

	banksel valve_cont2
	movlw B'00000000'
	movwf valve_cont2

	banksel valve_cont3
	movlw B'00000000'
	movwf valve_cont3

	banksel valve_cont4
	movlw B'00000000'
	movwf valve_cont4

;---------------------------------------------------------------------------------------------
;	                ABILITAZIONE DEGLI INTERRUPT DOVUTI A:
;
;	                 - buffer0 di ricezione del modulo CAN
;               	 - buffer1 di ricezione del modulo CAN
;---------------------------------------------------------------------------------------------
	banksel RCON
	movlw B'00000000'
	movwf RCON		;disabilito interrupt priorizzati

	banksel INTCON
	movlw B'00000000'
	movwf INTCON		;abilitazione generale interrupt (bit 7)verrà fatta successivamente finita la configurazione
						;abilitazione interrupt da periferiche (bit 6)verrà fatta successivamente finita la configurazione

	banksel INTCON2 ;disabilito tutti questi interrupt per evitare che alcuni influiscano sul funzionamento del micro.
	movlw B'00000000'
	movwf INTCON2		

	banksel INTCON3
	movlw B'00000000'
	movwf INTCON3		

	banksel PIR1		;azzero tutti i flag di tutti gli interrupt (anche quelli che non utilizzerò)
	movlw B'00000000'
	movwf PIR1

	banksel PIR2
	movlw B'00000000'
	movwf PIR2

	banksel PIR3
	movlw B'00000000'
	movwf PIR3

	banksel PIE1		;disabilito tutti gli interrupt relativi a questo registro
	movlw B'00000000'
	movwf PIE1

	banksel PIE2
	movlw B'00000000'	;disabilito tutti gli interrupt relativi a questo registro
	movwf PIE2

	banksel PIE3		
	movlw B'00000000'	;disabilito tutti gli interrupt relativi a questo registro
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
	;QUESTO CICLO APPENA FATTO SERVE PER "ASPETTARE" CHE IL PIC SIA IN CONFIGURATION MODE...FINCHE' NON E' IN CONFIGURATION MODE LUI NON VA AVANTI

;------------------------ BAUDRATE--------------------------------------------------------------
	;Impostiamo il Baud rate 1Mbit/s

	banksel	BRGCON1
						  	;SETTO SYNCRO JUMP WIDTH di 1Tq E BAUD RATE PRESCALER = 1
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

	banksel	RXB0CON
	
	bcf RXB0CON,7; il buffer 0 è pronto a ricevere un nuovo dato
	bcf RXB0CON,6;il bit 6 e 5 serve per dirgli che ricevono solo byte con maschera standard
	bsf RXB0CON,5;
	bcf RXB0CON,4;non implementato
	bcf RXB0CON,3;no remote transfer request
	bcf RXB0CON,2;un overflow non abilitato
	bcf RXB0CON,1;jump tra 0 e 1
	bcf RXB0CON,0;qua gli diciamo di leggere il filtro 0

	banksel	RXF0SIDH		;filtro 0 riceve solo ID del tipo 00001000/001
	movlw	B'00001000'   	;configuro i primi 8 bit del filtro 0
	movwf	RXF0SIDH
	
	banksel	RXF0SIDL
	movlw	B'00100000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF0SIDL		;filtro per messaggio tempi reogazione

	banksel	RXF1SIDH		;filtro 1 riceve solo ID del tipo 00001000/010
	movlw	B'00001000'   	;configuro i primi 8 bit del filtro 1
	movwf	RXF1SIDH
	
	banksel	RXF1SIDL
	movlw	B'01000000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF1SIDL		;filtro per messaggio reset (per ora non implementato)
	
	banksel	RXM0SIDH
	movlw	B'11111111'   	;configuro i primi 8 bit della maschera 0
	movwf	RXM0SIDH
	
	banksel	RXM0SIDL
	movlw	B'11100000'   	;configuro i restanti 3 bit della maschera==> se il messaggio non ha id esattamente uguale a quello richiesto il messaggio non passa
	movwf	RXM0SIDL


;---------------------------------------------------------------------------	
;													BUFFER 1 
	
	banksel	RXB1CON
	movlw	B'00100000'  	;configuro il buffer 1 di ricezione con il filtro 1...questo l'ho fatto mettendo il bit 0 a 1
	movwf	RXB1CON

	banksel	RXF2SIDH		;filtro 2 riceve solo ID del tipo 00001000/011
	movlw	B'00001000' 	;configuro i primi 8 bit del filtro 2
	movwf	RXF2SIDH
	
	banksel	RXF2SIDL
	movlw	B'01100000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF2SIDL		;filtro per messaggio richiesta livelli da parte del master

	banksel	RXF3SIDH		;filtro 3 riceve solo ID del tipo 00001000/100
	movlw	B'00001000' 	;configuro i primi 8 bit del filtro 3
	movwf	RXF3SIDH
	
	banksel	RXF3SIDL
	movlw	B'10000000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF3SIDL

	banksel	RXF4SIDH		;filtro 4 riceve solo ID del tipo 00001000/101
	movlw	B'00001000' 	;configuro i primi 8 bit del filtro 4
	movwf	RXF4SIDH

	banksel	RXF4SIDL
	movlw	B'10100000'  	;configuro i restanti 3 bit e abilito l'ID solo di standard messages (bit3=0)
	movwf	RXF4SIDL


	banksel	RXM1SIDH
	movlw	B'11111111'   	;configuro i primi 8 bit della maschera 1
	movwf	RXM1SIDH

	banksel	RXM1SIDL
	movlw	B'11100000'  	;configuro i restanti 3 bit della maschera==> se il messaggio non ha id esattamente uguale a quello richiesto il messaggio non passa
	movwf	RXM1SIDL
;----------------------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------------------
;											REGISTRI TX	

	banksel	TXB0CON

	bcf TXB0CON,7;non implementato
	bcf TXB0CON,6;messaggio non abortito (è un flag...ora lo imposto a 0, si attiverà se necessario)
	bcf TXB0CON,5;il messaggio non perde arbitrarietà quando ricevuto
	bcf TXB0CON,4;c'è stato un errore (è un flag...ora lo imposto a 0, si attiverà se necessario)
	bcf TXB0CON,3;stato della richiesta (è un flag...ora lo imposto a 0, si attiverà se necessario)
	bcf TXB0CON,2;unimplemented
	bcf TXB0CON,1;Priorità di livello basso con gli ultimi due bit a 0
	bcf TXB0CON,0;Priorità di livello basso con gli ultimi due bit a 0
;--------------------------------------------------------------------------------------------	
;									esco dal configuration mode	
	
	
	banksel	CANCON
	movlw	B'00000000'  	;attivo il modulo CAN in normal mode
	movwf	CANCON


	banksel CANSTAT

NORMALMODE

	btfsc 	CANSTAT,OPMODE2	;questi cicli servono per verificare di essere tornati in normal mode
	goto 	NORMALMODE

	btfsc 	CANSTAT,OPMODE1		;questi cicli servono per verificare di essere tornati in normal mode
	goto 	NORMALMODE

	btfsc 	CANSTAT,OPMODE0		;questi cicli servono per verificare di essere tornati in normal mode
	goto 	NORMALMODE

;----------------------------------------------------------------------------------------------------
;Ora accendo il led di corretto funzionamento...in pratica se il led si accende sappiamo che il micro è stato settato in maniera corretta.
	banksel PORTE
	bsf PORTE,1

;************************************************************************************************
;                                   PROGRAMMA PRINCIPALE
;************************************************************************************************
WAIT_REFILL

	banksel INTCON
	bcf INTCON,7
	bcf INTCON,6
; disabilito abilito gli interrupt generali

	banksel PIE3
	bcf PIE3,1
	bcf PIE3,0
;disabilito gli interrupt relativi al buffer 0 e 1 pieno....mi servono per la ricezione CAN..
;----------------------------------------------------------------------------------------------------

	banksel flag		
	movlw B'00000000'
	movwf flag

	nop
	nop
	call Check_Levels
	nop
	banksel Levels
	TSTFSZ Levels
	goto WAIT_REFILL	
	nop

;abilito gli interrupt di ricezione via can. Questa è una ridondanza software di controllo. Noi non andiamo ad erogare mai finchè i livelli dei galleggianti non sono ok perchè 
;gli interrutp di ricezione can non sono attivi.

	banksel INTCON
	bsf INTCON,7
	bsf INTCON,6
; abilitatti gli interrupt generali

	banksel PIE3
	bsf PIE3,1
	bsf PIE3,0
	;abilito gli interrupt relativi al buffer 0 e 1 pieno....mi servono per la ricezione CAN..
;----------------------------------------------------------------------------------------------------

	nop
WAIT_TIMES
	nop
	nop
	nop
	nop
	banksel flag
	btfsc flag,0 ;Controllo se è appena stata effettuata un'erogazione. Seè stataeffettuata il bit 0 di flag è =1 per cui torno allo stato Check_Levels
	goto WAIT_REFILL	
	goto WAIT_TIMES
	nop
	nop
;************************************************************************************************
;											ROUTINE
;************************************************************************************************

; all'inizio di questa routine andiamo ad azzerare le variabili Levels che useremo di volta in volta
;andiamo ad acquisire 3 volte ad un intervallo di 0.2 secondi i livelli dei galleggianti e li memorizziamo in 3 varabili
;dopo aver fatto ciò, li confrontiamo, se sono diversi ricominciamo l'acquisizione.
;se sono uguali mandiamo via CAN un messaggio al master dove con i primi 4 bit andiamo a comunicare se i galleggianti sono o meno alzati

Check_Levels
	nop
	banksel Levels
	clrf Levels; pulisco la variabile Levels per la nuova acquisizione
	nop
	nop
	nop
	btfsc PORTA,0;testiamo il galleggiante 1 e se è alzato andiamo a settare livello alto il bit 0 della variabile Levels, così verrà fatto per gli altri galleggianti
	bsf Levels,0
	btfsc PORTA,1
	bsf Levels,1
	btfsc PORTA,2
	bsf Levels,2
	btfsc PORTA,3
	bsf Levels,3
	nop
	nop


;attesa di 0,2 secondi tra le acquisizioni
	banksel cont2
	movlw D'6' ;circa 0.25 secondi
	movwf cont2
	nop
	call DELAY
	
	nop
	nop

	banksel Levels2
	clrf Levels2; pulisco la variabile Levels per la nuova acquisizione
	nop
	nop
	nop
	btfsc PORTA,0;testiamo il galleggiante 1 e se è alzato andiamo a settare livello alto il bit 0 della variabile Levels2, così verrà fatto per gli altri galleggianti
	bsf Levels2,0
	btfsc PORTA,1
	bsf Levels2,1
	btfsc PORTA,2
	bsf Levels2,2
	btfsc PORTA,3
	bsf Levels2,3
	nop

	banksel cont2
	movlw D'6' ;circa 0.25 secondi
	movwf cont2

	call DELAY

	nop
	nop
	banksel Levels3
	clrf Levels3; pulisco la variabile Levels per la nuova acquisizione
	nop
	nop
	nop
	btfsc PORTA,0;testiamo il galleggiante 1 e se è alzato andiamo a settare livello alto il bit 0 della variabile Levels3, così verrà fatto per gli altri galleggianti
	bsf Levels3,0
	btfsc PORTA,1
	bsf Levels3,1
	btfsc PORTA,2
	bsf Levels3,2
	btfsc PORTA,3
	bsf Levels3,3
	
	nop
;usiamo  il comando CPFSEQ per comparare le variabili Levels1,2,3...se sono diverse ricominciamo immediatamente le acquisizioni

	movf Levels,W
	CPFSEQ Levels2
	goto Check_Levels
	nop
	CPFSEQ Levels3
	goto Check_Levels
	nop; ora dato che le variabili temporanee levels sono uguali comunichiamo il risultato delle acquisizioni al master via CAN
	nop
	
	
	banksel DATO
	clrf DATO
	movff Levels,DATO;abbiamo copiato il risultato delle acquisizioni nella variabile temporanea DATO e sucessivamente andremo a inviarla.
	nop
	nop

	banksel IDH
	movlw B'00001000' ; identificativo della comunicazione "risposta livelli" è 00001000101
	movwf IDH

	banksel IDL
	movlw B'10100000'
	movwf IDL

	banksel DLC
	movlw B'00000001'; trasmettiamo solo un byte
	movwf DLC
	nop
	nop
	call Answer_To_Master
	nop
	nop
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RECEIVE;FUNZIONA PERFETTAMENTE
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

	banksel RXB0D1
	movff RXB0D1, temp_d1

	banksel RXB0D2
	movff RXB0D2, temp_d2

	banksel RXB0D3
	movff RXB0D3, temp_d3
	nop
	nop
	nop
	return

	nop
	nop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Answer_To_Master;FUNZIONA PERFETTAMENTE

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
		goto	Answer_To_Master
trasmissione_positiva		
		return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

DELAY;FUNZIONA PERFETTAMENTE
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

Open_Valves;FUNZIONA PERFETTAMENTE
	nop

	movlw B'00000000'
	banksel PORTC_app

	CPFSEQ valve_cont1 ;confronta il registro valvlcont1 con w, se sono uguali skippa
	bsf PORTC_app,7

	CPFSEQ valve_cont2
	bsf PORTC_app,4

	banksel PORTD_app

	CPFSEQ valve_cont3
	bsf PORTD_app,3

	CPFSEQ valve_cont4
	bsf PORTD_app,2

	movff PORTC_app,PORTC
	movff PORTD_app,PORTD
	
O_V ;Ogni 0.5 secondi decremento di uno i contatori assegnati ad ogni valvola e quando arrivano a zero
	;spengo il led ad essi assegnati 	
	nop
	nop
	nop
	
	banksel cont
	movlw D'12' ;in questo modo dovrei avere un ciclo che dura all'incirca 0.5 secondi
	movwf cont2
	
	call DELAY

	movlw B'00000000'
	
	banksel valve_cont1
	
	CPFSEQ valve_cont1 ;se il valore del contatore Ã¨ diverso da zero lo decremento di uno. Se
					 ;diventa zero spengo il led e mantengo il contatore sempre cosÃ¬
	call Dec1
	
	banksel valve_cont2
	CPFSEQ valve_cont2
	
	call Dec2

	banksel valve_cont3
	CPFSEQ valve_cont3
	
	call Dec3

	banksel valve_cont4
	CPFSEQ valve_cont4
	
	call Dec4

	movff PORTC_app,PORTC
	movff PORTD_app,PORTD

	nop
	nop
; FACCIAMO ora un test sui 4 contatori. Quando anche solo uno è diverso da 0 con un goto, riportiamo il programma all'inizio del contatore. 
; Quando per tutti è 4 i contatori il test è passato allora andiamo a un return che ci riporta nella routine di interrupt in alto.
	TSTFSZ valve_cont1
	goto O_V
	TSTFSZ valve_cont2
	goto O_V
	TSTFSZ valve_cont3
	goto O_V
	TSTFSZ valve_cont4
	goto O_V
	return


	nop
	nop
Dec1 
	DCFSNZ valve_cont1 ;decremento il contatore e se non è zero skippo l'istruzione che chiude il rubinetto
	bcf PORTC_app,7
	return

Dec2 
	DCFSNZ valve_cont2;decremento il contatore e se non è zero skippo l'istruzione che chiude il rubinetto
	bcf PORTC_app,4
	return

Dec3 
	DCFSNZ valve_cont3;decremento il contatore e se non è zero skippo l'istruzione che chiude il rubinetto
	bcf PORTD_app,3
	return

Dec4
	DCFSNZ valve_cont4 ;decremento il contatore e se non è zero skippo l'istruzione che chiude il rubinetto
	bcf PORTD_app,2
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	end	