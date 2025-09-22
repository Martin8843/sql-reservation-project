-- =========================================================================
/*
	Plik do zadania 3: 03_test.sql
	Tytuł: Przypadki testowe dla stworzonej procedury reerwacji biletów.
	Data: 2025-09-03
	Uwagi: 
	/*
	
  1. Pojedyncze wywołania:
     - test udanej rezerwacji dla jednego PESEL
     - ponwna próba dla tego samego PESEL (sprawdznie obsługi duplikatu)
     - wyśwetlanie statusu i wygenerowanego UUID

  2. Test limitu rezerwacji:
     - ustawienie licznika na 0
     - czyszczenie tabel przed uruchomieniem
     - symulacja przeroczenia limitu (limit = 50 w procedurze, próbujemy 52)
     - sprawdzenie statusów i wypełnienia tabel

  3. Test równoległych sesji:
     - czyszczenie tabel i zerowanie licznika
	 - sprawdzenie uprawnień
     - symulacja 50 niezaeżnych użytkowników wywołujących procedurę
     - wykorzytanie DBMS_SCHEDULER (każdy job w osobnej sesji)
     - każdy job wywołuje p_reserve_ticket z unikanym PESEL
     - auto_dop = TRUE → joby usuwają się po wykonaniu
     - po tetach weryfikacja tabel i statusów
     - sprawdzenie szczegółów uruchomień jobów (np. all_scheduler_job_run_details)
     - weryfikacja, że joby zniknęły (user_scheduler_jobs)
*/

-- =========================================================================

--1.
DECLARE
  v_status NUMBER;
  v_idr    RAW(16);
BEGIN
  p_reserve_ticket('12345378901', v_status, v_idr);
  -- wypisuje wynik an konsole, uzywam konwersja wartości typu RAW(16) na czytelny format.
  DBMS_OUTPUT.PUT_LINE('STATUS=' || v_status || ' | IDR=' || RAWTOHEX(v_idr));
END;
/

DECLARE
  v_status  NUMBER;
  v_idr     RAW(16);
BEGIN
  p_reserve_ticket('12345678901', v_status, v_idr);
  DBMS_OUTPUT.PUT_LINE('STATUS=' || v_status || ' | idr=' || RAWTOHEX(v_idr));
END;
/

--2.

UPDATE reservation_counter SET reserved = 0 WHERE counter_id = 1;

TRUNCATE TABLE reservation_tickets;
TRUNCATE TABLE log_reservation;
UPDATE reservation_counter SET reserved = 0 WHERE counter_id = 1;
COMMIT;


DECLARE
  v_status NUMBER;
  v_idr    RAW(16);
BEGIN
  FOR i IN 1..52 LOOP
  --generuje unikalne pesele dla kazdej oepracji w petli
    p_reserve_ticket(LPAD(i,11,'0'), v_status, v_idr);
    DBMS_OUTPUT.PUT_LINE('PESEL='||LPAD(i,11,'0')||' STATUS='|| v_status);
  END LOOP;
END;
/


--3.
TRUNCATE TABLE reservation_tickets;
TRUNCATE TABLE log_reservation;
UPDATE reservation_counter SET reserved = 0 WHERE counter_id = 1;

COMMIT;


GRANT EXECUTE ON DBMS_SCHEDULER TO twoj_uzytkownik;
GRANT CREATE JOB TO twoj_uzytkownik ;

 BEGIN
   FOR i IN 1..50 LOOP     
    DBMS_SCHEDULER.CREATE_JOB(
       job_name        => 'testowy_job_'|| i || '_' || DBMS_RANDOM.STRING('X',4), --nazwa joba unikalna musi być
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'DECLARE v_status NUMBER; v_idr RAW(16);
                           BEGIN p_reserve_ticket(''' || LPAD(i,11,'0') || ''', v_status, v_idr); END;',
       start_date      => SYSTIMESTAMP, 
       enabled         => TRUE, --wlaczony i silnik planuje od razu jego wykonanie
       auto_drop       => TRUE 
     );
   END LOOP;
   END;
   
-- po weryfiakcji tabel widze ze pesele zostaly wpisane, statusy sa prawidlowe zatem rownoleglosc dziala.
   
SELECT *
  FROM all_scheduler_job_run_details;

SELECT job_name, state
  FROM user_scheduler_jobs
  WHERE job_name LIKE 'TESTOWY_JOB%';
  




