/*----------------------------------CLIENTE-----------------------------------*/
/*
	Il cliente arriva alla cassa e vuole pagare, cerco la sua prenotazione e restituisco il costo totale
*/
select CostoTot
from Prenotazione
where DataInizio = '20-Sep-2018'
and DataFine = '25-Sep-2018'
and NumeroCamera = 303


/*
	Un cliente vuole sapere tutte le prenotazioni che ha effettuato nel nostro Hotel
*/
select DataInizio,DataFine,CostoTot,NumeroCamera
from Prenotazione
where CF = 'MRCSMZ66Y67H223W'
order by DataInizio



/*---------------------------------PROPRIETARIO-------------------------------*/

/*
	Il proprietario desidera visionare tutti gli stipendi dei receptionist

	Per questo si faccia riferimento alla vista "Stipendi" creata nel file hotel.sql
*/



/*
	Il proprietario desidera sapere l'ammontare delle entrate di tutto il 2018
*/
select sum(CostoTot)
from Prenotazione
where DataInizio between '01-Jan-2018' and '31-Dec-2018'
and DataFine between '01-Jan-2018' and '31-Dec-2018'



/*
	Il proprietario vorrebbe sapere quali sono i clienti che spendono di più,
	in particolare quelli che hanno superato i 1000€ in almeno una prenotazione.
*/
select distinct Nome,Cognome
from Cliente c
where exists
(
	select *
	from Prenotazione p
	where c.CF = p.CF
	and CostoTot > 1000
)




/*
	Il proprietario è curioso di sapere quante persone sono state in hotel durante il mese di settembre
*/
select sum(NumPersone) Persone, count(*) Prenotazioni
from Prenotazione
where DataInizio between '01-Sep-2018' and '30-Sep-2018'
and DataFine between '01-Sep-2018' and '30-Sep-2018'



/*
	Ogni mese, dopo aver pagato tutti gli stipendi, essi vengono azzerati per poter "ripartire" da zero
*/
update Receptionist
set Stipendio = 0;
update PersonalePulizie
set Stipendio = 0



/*
	Vengono mostrati tutti quei clienti (e la relativa prenotazione) i quali hanno usufruito sia
	del posto auto sia del ristorante.
*/
select Nome,Cognome,CodPrenotazione
from Cliente, Prenotazione
where Cliente.CF = Prenotazione.CF
and CodPrenotazione in
(
	select CodPrenotazione
	from PostoAuto
)
and CodPrenotazione in
(
	select CodPrenotazione
	from Riservare
)
order by Cognome



/*----------------------------------DIPENDENTE--------------------------------*/

/*
	Un receptionist vuole visualizzare tutti i turni che ha effettuato nel mese di settembre
*/
select Giorno, FasciaGiornaliera
from TurnoReception
where CF = 'TGRFTG76T56H225Q'
and Giorno between '01-Sep-2018' and '30-Sep-2018'



/*
	Un dipendente vuole sapere, per il mese di Settembre, quante camere ha pulito e in quali giorni
*/
select Giorno, count(*) Camere_Pulite
from TurnoPulizie
where CF = 'PLNRDC88G53M883T'
and Giorno between '01-Sep-2018' and '30-Sep-2018'
group by Giorno
