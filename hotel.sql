/*
* ----------------------Creazione Domain--------------------------------
*/

create domain SezioniGiornata
	as varchar(10)
check
(
	value='Mattino' OR
	value='Pomeriggio' OR
	value='Sera' OR
	value='Notte'
/*
	Mattino = 7:00 - 13:00
	Pomeriggio = 13:00 -19:00
	Sera = 19:00 - 1:00
	Notte = 1:00 - 7:00
*/
);



/*
* --------------------------Query di creazione--------------------------
*/



create table Dipendente
(
	CF char(16) primary key,
	Nome varchar(30) not null,
	Cognome varchar(30) not null
);



create table Sconto
(
	CodOfferta char(5) primary key,
	Descrizione varchar(100),
	Percentuale smallint not null,

	check ((Percentuale>0) and (Percentuale<100))
);



create table Cliente
(
	CF char(16) primary key,
	Nome varchar(30) not null,
	Cognome varchar(30) not null,
	CodOfferta char(5) unique,

	foreign key (CodOfferta) references Sconto(CodOfferta)
		on delete no action on update cascade
);



create table Dirigente
(
	CF char(16) primary key,
	Nome varchar(30) not null,
	Cognome varchar(30) not null,
	Stipendio numeric(8,2) not null,

	check ((Stipendio>=0) and (Stipendio<=999999)),

	foreign key (CF) references Dipendente(CF)
		on delete no action on update cascade
);



create table PersonalePulizie
(
	CF char(16) primary key,
	Nome varchar(30) not null,
	Cognome varchar(30) not null,
	Stipendio numeric(8,2) not null,
	CFDirigente char(16) not null,

	check ((Stipendio>=0) and (Stipendio<=999999)),

	foreign key (CFDirigente) references Dirigente(CF)
		on delete no action on update cascade,

	foreign key (CF) references Dipendente(CF)
		on delete no action on update cascade
);



create table Receptionist
(
	CF char(16) primary key,
	Nome varchar(30) not null,
	Cognome varchar(30) not null,
	Stipendio numeric(8,2) not null,
	CFDirigente char(16) not null,

	foreign key (CFDirigente) references Dirigente(CF)
		on delete no action on update cascade,

	foreign key (CF) references Dipendente(CF)
		on delete no action on update cascade
);



create table TurnoReception
(
	Giorno date,
	FasciaGiornaliera SezioniGiornata,
	RetribuzioneOraria numeric(4,2),
	CF char(16) not null,
	CFSostituto char(16),

	check(RetribuzioneOraria >=0),

	primary key (Giorno, FasciaGiornaliera),

	foreign key (CF) references Receptionist(CF)
		on delete no action on update cascade,

	foreign key (CFSostituto) references Receptionist(CF)
		on delete no action on update cascade
);



create table Camera
(
	NumeroCamera smallint primary key,
	NPosti smallint not null,
	CostoNotte numeric(6,2) not null,
	Cauzione smallint not null,

	check ( (NumeroCamera>0) and (NPosti>0) and (CostoNotte>=0) and (Cauzione>=0) and (Cauzione<=1000) )
);



create table TurnoPulizie
(
	Giorno date,
	NumeroCamera smallint,
	RetribuzioneOraria numeric(4,2) not null,
	CF char(16) not null,
	CFSostituto char(16),

	check(RetribuzioneOraria >=0),

	primary key (Giorno,NumeroCamera),

	foreign key (NumeroCamera) references Camera(NumeroCamera)
		on delete no action on update cascade,

	foreign key (CF) references PersonalePulizie(CF)
		on delete no action on update cascade,

	foreign key (CFSostituto) references PersonalePulizie(CF)
		on delete no action on update cascade
);



create table PromozioneGiornaliera
(
	DataPromozione date primary key,
	Percentuale smallint not null,
	Titolo varchar(50) not null,

	check ((Percentuale>0) and (Percentuale<100))
);



create table Prenotazione
(
	CodPrenotazione char(8) not null unique,
	/*
		L'attributo CodPrenotazione è chiave secondaria. La chiave composta
		rimane primaria poichè continene informazioni importanti, mentre
		questa chiave secondaria viene utilizzata per comodità nelle Query
		di accesso al DataBase.
	*/
	DataInizio date not null,
	DataFine date not null,
	Numerocamera smallint not null,
	NumPersone smallint not null,
	CostoTot numeric (7,2) not null,
	DataPromozione date,
	CF char(16) not null,

	check ( (DataInizio<DataFine) and (NumPersone>0) and (CostoTot>=0) ),

	primary key (DataInizio, DataFine, NumeroCamera),

	unique (CodPrenotazione),

	foreign key (NumeroCamera) references Camera(NumeroCamera)
		on delete no action on update cascade,

	foreign key (DataPromozione) references PromozioneGiornaliera(DataPromozione)
		on delete no action on update cascade,

	foreign key (CF) references Cliente(CF)
		on delete no action on update cascade
);



create table PostoAuto
(
	Posto smallint,
	CodPrenotazione char(8),
	CostoGiornaliero numeric(4,2),

	check( (Posto>0) and (CostoGiornaliero>=0) ),

	primary key (Posto, CodPrenotazione),

	foreign key (CodPrenotazione) references Prenotazione(CodPrenotazione)
		on delete no action on update cascade
);




create table Riservare
(
	Data date,
	Ora time,
	NumeroTavolo smallint,
	Posti smallint not null,
	CostoPersona numeric(5,2),
	CodPrenotazione char (8) not null,

	check( (Posti>0) and (CostoPersona>=0) ),

	primary key(Data, Ora, NumeroTavolo),

	foreign key (CodPrenotazione) references Prenotazione(CodPrenotazione)
		on delete no action on update cascade
);




/*
*--------------------------------------VIEW--------------------------------
*/


create view Stipendi as
(select Nome,Cognome,Stipendio
from Receptionist)
union
(select Nome,Cognome,Stipendio
from PersonalePulizie)
order by Cognome;






/*
*----------------------TRIGGERS-----------------------------
*/

/*	Trigger 1)

	Controllo date camera: la camera prenotata deve essere libera in quel lasso
	di tempo.
*/
create function controllo_camera()
returns trigger as $controllo_camera$

	begin
	/*Seleziono DataInizio e DataFine di tutte le prenotazioni le cui date sono in conflitto con altre.
	Se questo numero è maggiore di zero allora sto inserendo una prenotazione errata*/
		if ( select count(*)
			from (select new.DataInizio, new.DataFine
				from Prenotazione p
				where exists
					(
					select *
					from Prenotazione p2
					where (((p.DataInizio >= p2.DataInizio)
						and (p.DataInizio <= p2.DataFine))
						or
						((p.DataFine >= p2.DataInizio)
						and (p.DataFine <= p2.DataFine)))
					and p2.NumeroCamera = p.NumeroCamera
					and p2.CodPrenotazione != p.CodPrenotazione)
				) as c ) > 0
		then
			raise exception 'La Prenotazione non può essere effettuata, la camera selezionata risulta già occupata.
			Si consiglia di cambiare camera o modificare le date selezionate.';
		end if;
	return new;
	end;
$controllo_camera$ language plpgsql;

create trigger controllo_camera
after insert or update on Prenotazione
for each row
execute procedure controllo_camera();





/*	Trigger 2)

	Controllo ospiti camera: il numero di ospiti deve essere <= al numero di
	posti della camera.
*/
create function controllo_ospiti()
returns trigger as $controllo_ospiti$
	begin
		if new.NumPersone >
			(select NPosti
			from Camera
			where NumeroCamera = new.NumeroCamera)
		then
			raise exception 'Numero ospiti errato!';
		end if;
	return new;
	end;
$controllo_ospiti$ language plpgsql;

create trigger controllo_ospiti
before insert on Prenotazione
for each row
execute procedure controllo_ospiti();





/*	Trigger 3)

	Funzione che inserisce il costo della camera nel costo totale.
	Se la prenotazione o il cliente hanno uno sconto, viene applicato
	il massimo dei due.
*/
create function costo_camera()
returns trigger as $costo_camera$
	declare
		n_notti smallint;
		data_inizio date;
		data_fine date;
		costo numeric(7,2);
		perc_prenotazione smallint;
		perc_cliente smallint;
		perc real;

	begin
	/*inizalizzo le variabili*/
		data_inizio := (select DataInizio
			from Prenotazione
			where CodPrenotazione = new.CodPrenotazione);
		data_fine := (select DataFine
			from Prenotazione
			where CodPrenotazione = new.CodPrenotazione);
		n_notti := data_fine - data_inizio;
		costo := (select CostoNotte
			from Camera
			where NumeroCamera = new.NumeroCamera);
		perc_prenotazione := (select PG.Percentuale
			from Prenotazione as P, PromozioneGiornaliera as PG
			where P.CodPrenotazione = new.CodPrenotazione
			and P.DataPromozione = PG.DataPromozione);
		perc_cliente := (select S.Percentuale
			from Prenotazione as P, Cliente as C, Sconto as S
			where P.CodPrenotazione = new.CodPrenotazione
			and P.CF = C.CF
			and C.CodOfferta = S.CodOfferta);

	/*Assegno a percentuale il valore maggiore tra promozione giornaliera e sconto*/
		if ((perc_prenotazione <> 0) and (perc_cliente <> 0)) then
			if (perc_cliente > perc_prenotazione) then
				perc := perc_cliente;
			else
				perc := perc_prenotazione;
			end if;
		else
			if (perc_cliente <> 0) then
				perc := perc_cliente;
			else
				perc := perc_prenotazione;
			end if;
		end if;

	/*Aggiorno il valore CostoTot, e se necessario sottraggo lo sconto*/

		if (perc <> 0)
		then
			costo := costo * n_notti;
			perc := 1 - perc/100;
			update Prenotazione
			set CostoTot = costo * perc
			where CodPrenotazione = new.CodPrenotazione;
		else
			update Prenotazione
			set CostoTot = costo * n_notti
			where CodPrenotazione = new.CodPrenotazione;
		end if;

	return new;
	end;
$costo_camera$ language plpgsql;

create trigger costo_camera
after insert on Prenotazione
for each row
execute procedure costo_camera();





/*	Trigger 4)

	Assicurarsi che ogni dipendente della reception effettui al massimo un turno al giorno.
*/
create function max_turni_reception()
returns trigger as $max_turni_reception$
	begin
		if (select count (*)
			from (select *
				from TurnoReception t
				where exists
				(
					select *
					from TurnoReception t2
					where t.CF = t2.CF
					and t.Giorno = t2.Giorno
					and t.FasciaGiornaliera != t2.FasciaGiornaliera
				)) as c) > 0
		then
			raise exception 'Il turno inserito non è valido, un dipendente può effettuare al più un turno al giorno.';
		end if;

	return new;
	end;
$max_turni_reception$ language plpgsql;

create trigger max_turni_reception
after insert or update on TurnoReception
for each row
execute procedure max_turni_reception();





/*	Trigger 5)

Aggiornare dato derivato CostoTot ogni volta che viene prenotato un posto auto.
*/

create function aggiorna_costo_auto()
returns trigger as $aggiorna_costo_auto$
	declare
		costo numeric(7,2);
		notti smallint;
	begin
		notti := (select DataFine
			from Prenotazione
			where CodPrenotazione = new.CodPrenotazione)
			-
			(select DataInizio
			from Prenotazione
			where CodPrenotazione = new.CodPrenotazione);

		costo:= (select CostoGiornaliero
			from PostoAuto
			where CodPrenotazione = new.CodPrenotazione
			and Posto = new.Posto);

		costo := costo * notti;

		update Prenotazione
		set CostoTot = CostoTot + costo
		where CodPrenotazione = new.CodPrenotazione;

	return new;
	end;
$aggiorna_costo_auto$ language plpgsql;

create trigger aggiorna_costo_auto
after insert or update	on PostoAuto
for each row
execute procedure aggiorna_costo_auto();






/*	Trigger 6)

	Aggiornare il CostoTot ogni volta che viene prenotato un tavolo al Ristorante
*/

create function aggiorna_costo_ristorante()
returns trigger as $aggiorna_costo_ristorante$
	declare
		costo numeric(7,2);

	begin
		costo:= (select CostoPersona
			from Riservare
			where Data = new.Data
			and Ora = new.Ora
			and NumeroTavolo = new.NumeroTavolo)
			*
			(select Posti
			from Riservare
			where Data = new.Data
			and Ora = new.Ora
			and NumeroTavolo = new.NumeroTavolo);

		update Prenotazione
		set CostoTot = CostoTot + costo
		where CodPrenotazione = new.CodPrenotazione;

	return new;
	end;
$aggiorna_costo_ristorante$ language plpgsql;

create trigger aggiorna_costo_ristorante
after insert or update	on Riservare
for each row
execute procedure aggiorna_costo_ristorante();






/*	Trigger 7)

	Aggiorna stipendio reception
*/
create function stipendio_reception()
returns trigger as $stipendio_reception$
	declare
		costo numeric (8,2);

	begin
		costo := (select RetribuzioneOraria
			from TurnoReception
			where Giorno = new.Giorno
			and FasciaGiornaliera = new.FasciaGiornaliera)
			* 6;

		update Receptionist
		set Stipendio = Stipendio + costo
		where CF = new.CF;
	return new;
	end;
$stipendio_reception$ language plpgsql;

create trigger stipendio_reception
after insert or update on TurnoReception
for each row
execute procedure stipendio_reception();







/*	Trigger 8)

	Aggiorna stipendio personale pulizie
*/
create function stipendio_personale_pulizie()
returns trigger as $stipendio_personale_pulizie$
	declare
		costo numeric(8,2);

	begin
		costo := (select RetribuzioneOraria
			from TurnoPulizie
			where Giorno = new.Giorno
			and NumeroCamera = new.NumeroCamera);

		update PersonalePulizie
		set Stipendio = Stipendio + costo
		where CF = new.CF;

	return new;
	end;
$stipendio_personale_pulizie$ language plpgsql;

create trigger stipendio_personale_pulizie
after insert or update on TurnoPulizie
for each row
execute procedure stipendio_personale_pulizie();





/*	Trigger 9)

	Controllare che un tavolo sia libero in quella fascia oraria.
*/
create function controllo_tavolo()
returns trigger as $controllo_tavolo$
	begin
		if (select count (*)
			from (select *
				from Riservare
				where Data = new.Data
				and NumeroTavolo = new.NumeroTavolo
				and Ora != new.Ora
				and ( select abs(extract (epoch from (Ora - new.Ora))::real/3600)) <=3
				) as c
			) > 0
		then
			raise exception 'Il tavolo selezionato sarà già occupato in questo orario.';
		end if;

	return new;
	end;
$controllo_tavolo$ language plpgsql;

create trigger controllo_tavolo
after insert or update on Riservare
for each row
execute procedure controllo_tavolo();






/*	Trigger 10)

	Controllare che il posto auto sia libro per tutta la durata del soggiorno
*/
create function controllo_posto_auto()
returns trigger as $controllo_posto_auto$
	declare
		data_inizio date;
		data_fine date;

	begin
		data_inizio := (select DataInizio
			from Prenotazione p
			where CodPrenotazione = new.CodPrenotazione);

		data_fine := (select DataFine
			from Prenotazione
			where CodPrenotazione = new.CodPrenotazione);

		if (select count(*)
			from (select *
				from PostoAuto pa, Prenotazione p
				where pa.CodPrenotazione = p.CodPrenotazione
				and pa.Posto = new.Posto
				and pa.CodPrenotazione != new.CodPrenotazione
				and (((p.DataInizio >= data_inizio)
					and (p.DataInizio <= data_fine))
					or
					((p.DataFine >= data_inizio)
					and (p.DataFine <= data_fine)))
				) as c) > 0
		then
			raise exception 'Il posto auto selezionato è già occupato in queste date.';
		end if;

	return new;
	end;
$controllo_posto_auto$ language plpgsql;

create trigger controllo_posto_auto
after insert or update on PostoAuto
for each row
execute procedure controllo_posto_auto();







/*	Trigger 11)

	Trigger che si assicura che ogni dipendente pulisca al massimo 6 camere al giorno.
*/
create function max_turni_pulizie()
returns trigger as $max_turni_pulizie$
	begin
		if (select count (*)
			from (select *
				from TurnoPulizie t
				where t.CF = new.CF
				and t.Giorno = new.Giorno
				) as c
			) > 6
		then
			raise exception 'Il turno inserito non è valido, un dipendente può pulire al più 6 camere al giorno.';
		end if;
	return new;
	end;
$max_turni_pulizie$ language plpgsql;

create trigger max_turni_pulizie
after insert or update on TurnoPulizie
for each row
execute procedure max_turni_pulizie();






/*
*----------------------Query di inserimento-----------------------------
*/


insert into Dipendente values('TGRFTG76T56H225Q','Matteo','Pietri');
insert into Dipendente values('PNTRCA39J77B291C','Giovanni','Bottazzi');
insert into Dipendente values('PLNRDC88G53M883T','Marta','Galati');
insert into Dipendente values('TGBOKN65R59G261V','Riccardo','Marata');
insert into Dipendente values('OMRVET74B29V345T','Greta','Ascari');
insert into Dipendente values('ABCRTG25R88G441W','Mattia','Alberti');
insert into Dipendente values('ZZZERF45V52G998K','Ambra','Maccari');
insert into Dipendente values('QWEVGT28P71J665F','Sofia','Montanari');
insert into Dipendente values('RFVTGB85O19A257O','Alessandro','Teggi');




insert into Sconto values('ABC23','Sconto fedeltà +5 prenotazioni',5);
insert into Sconto values('NNN77','Sconto fedeltà +3 visite in un anno',10);


insert into Cliente values('MRCSMZ66Y67H223W','Marco','Simonazzi');
insert into Cliente values('POIYTR87G54N546F','Silvia','Lo Verde','ABC23');
insert into Cliente values('PLMFCR64T37H337Q','Filippo','Onesti','NNN77');
insert into Cliente values('BHURDC64T38B503V','Silvia','Drago');
insert into Cliente values('BUYCSW74M99B375L','Giada','Calzolari');



insert into Dirigente values('PNTRCA39J77B291C','Giovanni','Bottazzi',5500.00);



insert into PersonalePulizie values('PLNRDC88G53M883T','Marta','Galati',0,'PNTRCA39J77B291C');
insert into PersonalePulizie values('OMRVET74B29V345T','Greta','Ascari',0,'PNTRCA39J77B291C');
insert into PersonalePulizie values('ABCRTG25R88G441W','Mattia','Alberti',0,'PNTRCA39J77B291C');



insert into Receptionist values('TGRFTG76T56H225Q','Matteo','Pietri',0,'PNTRCA39J77B291C');
insert into Receptionist values('TGBOKN65R59G261V','Riccardo','Marata',0,'PNTRCA39J77B291C');
insert into Receptionist values('ZZZERF45V52G998K','Ambra','Maccari',0,'PNTRCA39J77B291C');
insert into Receptionist values('QWEVGT28P71J665F','Sofia','Montanari',0,'PNTRCA39J77B291C');
insert into Receptionist values('RFVTGB85O19A257O','Alessandro','Teggi',0,'PNTRCA39J77B291C');




insert into TurnoReception values('7-Sep-2018','Notte',10,'TGRFTG76T56H225Q');
insert into TurnoReception values('8-Sep-2018','Mattino',9,'TGBOKN65R59G261V','RFVTGB85O19A257O');
insert into TurnoReception values('7-Sep-2018','Mattino',9,'ZZZERF45V52G998K');
insert into TurnoReception values('7-Sep-2018','Sera',9,'QWEVGT28P71J665F');
insert into TurnoReception values('8-Sep-2018','Notte',10,'TGRFTG76T56H225Q');
insert into TurnoReception values('7-Sep-2018','Pomeriggio',8,'RFVTGB85O19A257O');

/*
	Query errata per testare il Trigger numero 4
	insert into TurnoReception values('07-Sep-2018','Pomeriggio',8,'TGRFTG76T56H225Q');
*/


insert into Camera values(101,3,37.5,0);
insert into Camera values(102,4,55,0);
insert into Camera values(103,2,30,0);
insert into Camera values(201,4,63.5,50);
insert into Camera values(202,2,45,50);
insert into Camera values(203,4,70,50);
insert into Camera values(301,5,120,100);
insert into Camera values(302,3,95.5,100);
insert into Camera values(303,4,250,150);



insert into TurnoPulizie values('17-Sep-2018',101,6.5,'PLNRDC88G53M883T','OMRVET74B29V345T');
insert into TurnoPulizie values('18-Sep-2018',202,8,'OMRVET74B29V345T','ABCRTG25R88G441W');
insert into TurnoPulizie values('19-Sep-2018',303,9.5,'ABCRTG25R88G441W');
insert into TurnoPulizie values('17-Sep-2018',303,9.5,'PLNRDC88G53M883T');
insert into TurnoPulizie values('18-Sep-2018',303,9.5,'ABCRTG25R88G441W');
insert into TurnoPulizie values('19-Sep-2018',101,6.5,'PLNRDC88G53M883T');
insert into TurnoPulizie values('19-Sep-2018',102,6.5,'PLNRDC88G53M883T');
insert into TurnoPulizie values('19-Sep-2018',103,6.5,'PLNRDC88G53M883T');
insert into TurnoPulizie values('19-Sep-2018',201,8,'PLNRDC88G53M883T');
insert into TurnoPulizie values('19-Sep-2018',202,8,'PLNRDC88G53M883T');
insert into TurnoPulizie values('19-Sep-2018',203,8,'PLNRDC88G53M883T');
insert into TurnoPulizie values('19-Sep-2018',301,9.5,'ABCRTG25R88G441W');
insert into TurnoPulizie values('19-Sep-2018',302,9.5,'OMRVET74B29V345T');



insert into PromozioneGiornaliera values('24-Dec-2018',15,'Regalo di Natale');
insert into PromozioneGiornaliera values('8-Aug-2018',5,'Operazione Ferragosto');



insert into Prenotazione values('AAAA0001','17-Sep-2018','18-Sep-2018',101,3,0,'8-Aug-2018','MRCSMZ66Y67H223W');
insert into Prenotazione values('AAAA0002','20-Sep-2018','25-Sep-2018',303,3,0,'24-Dec-2018','POIYTR87G54N546F');
insert into Prenotazione values('AAAA0003','01-Sep-2018','07-Sep-2018',202,2,0,null,'PLMFCR64T37H337Q');
insert into Prenotazione values('AAAA0004','16-Sep-2018','21-Sep-2018',201,3,0,null,'BHURDC64T38B503V');
insert into Prenotazione values('AAAA0005','4-Sep-2018','6-Sep-2018',203,4,0,null,'BUYCSW74M99B375L');
insert into Prenotazione values('AAAA0006','7-Sep-2018','13-Sep-2018',303,3,0,null,'MRCSMZ66Y67H223W');
insert into Prenotazione values('AAAA0007','27-Sep-2018','30-Sep-2018',102,4,0,'24-Dec-2018','BHURDC64T38B503V');
insert into Prenotazione values('AAAA0008','14-Sep-2018','19-Sep-2018',301,5,0,null,'MRCSMZ66Y67H223W');

/*
	Query errata per testare il Trigger numero 1
	insert into Prenotazione values ('AAAA1111','19-Sep-2018','20-Sep-2018',201,3,0,null,'MRCSMZ66Y67H223W');

	Query errata per testare il Trigger numero 2
	insert into Prenotazione values('AAAA0005','23-Nov-2018','28-Nov-2018',103,4,0,null,'BUYCSW74M99B375L');
*/




insert into PostoAuto values(7,'AAAA0001',30);
insert into PostoAuto values(3,'AAAA0002',20);
insert into PostoAuto values(4,'AAAA0004',27);
insert into PostoAuto values(1,'AAAA0006',15);

/*
	Query errata per testare il Trigger numero 10
	insert into PostoAuto values(7,'AAAA0004',20);
*/




insert into Riservare values('18-Sep-2018','20:30',1,3,35,'AAAA0004');
insert into Riservare values('02-Sep-2018','13:00',4,2,25,'AAAA0003');
insert into Riservare values('20-Sep-2018','21:30',3,3,40,'AAAA0004');
insert into Riservare values('17-Sep-2018','13:00',6,3,25,'AAAA0001');
insert into Riservare values('22-Sep-2018','20:30',7,3,30,'AAAA0002');
insert into Riservare values('5-Sep-2018','13:30',2,4,20,'AAAA0005');
insert into Riservare values('28-Sep-2018','20:30',4,4,25,'AAAA0007');
insert into Riservare values('18-Sep-2018','21:00',5,5,40,'AAAA0008');

/*
	Query errata per testare il Trigger numero 9
	insert into Riservare values('18-Sep-2018','19:00',1,5,20,'AAAA0001');
*/
