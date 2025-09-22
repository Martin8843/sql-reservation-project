-- =========================================================================
/*
	Plik do zadania 3: 02_procdury.sql
	Tytuł: Tworzymy dwie procedury: biznesową i logującą (autonomiczna).
	Data: 2025-09-03
*/
-- =========================================================================



CREATE OR REPLACE PROCEDURE p_log_reservation (
    p_pesel         IN reservation_tickets.pesel%TYPE, 
    p_status        IN NUMBER,
    p_idr           IN reservation_tickets.idr%TYPE
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

    INSERT INTO log_reservation (pesel, date_register, status, idr)
    VALUES (p_pesel, SYSDATE, p_status, p_idr);
    COMMIT;
END p_log_reservation;
/

-- tworzenie glownej procedury
CREATE OR REPLACE PROCEDURE p_reserve_ticket (
                                                p_pesel    IN  VARCHAR2
                                                ,p_status  OUT NUMBER --parametr  bedzei przekazany z programu do śr.wywolania.
                                                ,p_idr     OUT RAW -- j.w
) IS
    v_limit CONSTANT NUMBER := 50000;
    v_idr RAW(16); 
    v_new_reserved NUMBER;  
    
	-- glowna logika w tym bloku procedury
BEGIN        
       /* 1. UPDATE ponizej zapewnia, że tylko jedna sesja na raz zwiększy wartość, jeśli warnek reserved < 50000 jest spełniony.
          sesja nr 1 robi UPDATE reserved = reserved + 1 i trzyma blokadę,
          sesja nr 2, 3, ... czekają,
          po COMMIT seji nr 1, puszcza blokadę i nastpna sesja robi UPDATE		  
		  2. RETURN; -- konczy procedure i przerywa wszystko po tym poleceniu
       */
      UPDATE reservation_counter
      SET reserved = reserved + 1
      WHERE counter_id = 1 -- w tabeli jest tylko jede wiersz i jego aktualizujemy 
      AND reserved < v_limit; 
    
	  -- jesli brak miejsc
	  -- przechowuje liczbe wierszy zmienionych przez ostatnia instrukcje dml
      IF SQL%ROWCOUNT = 0 THEN 
      p_status := 1;
      p_idr := NULL;
      p_log_reservation(p_pesel, p_status, NULL);
      RETURN;
      END IF;
    
    BEGIN
        v_idr := SYS_GUID();
        
        -- Wstawiamy nową rezerwcję do tabeli
        INSERT INTO reservation_tickets (idr, pesel, date_reservation)
        
        VALUES (v_idr, p_pesel, SYSDATE);

        -- ustawiam wartosci zwracane na zewnetrz proc
        p_status := 0;
        p_idr := v_idr; -- zwracam uui nowej rezerwacji

        -- wolam procedure logujaca
        p_log_reservation(p_pesel, p_status, p_idr);

        COMMIT; -- commit głównej trnsakcji
        RETURN;
        
    -- dodaje sekcje obslugi, aby zabezpieczyć się przed nieoczekiwanymi bledami i zachowania spojnsoci danych loguje wyjatek
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            -- PESEL już ma rezerwację, update licznika, w przecwinym razei licznik bylby zwiekszony a rezerwacja nie weszla
            UPDATE reservation_counter SET reserved = reserved - 1 WHERE counter_id = 1;
            COMMIT; -- zatwierdź cofnięcie licznika
            p_status := 2; -- np. 2 = "PEsEL już ma rezerację"
            p_idr := NULL;
            p_log_reservation(p_pesel, p_status, NULL);
            RETURN;

        WHEN OTHERS THEN
            -- pozostale błądy 
            UPDATE reservation_counter SET reserved = reserved - 1 WHERE counter_id = 1;
            COMMIT;
            p_status := 3; --
            p_idr := NULL;
            p_log_reservation(p_pesel, p_status, NULL);
            RETURN;
    END; 

END p_reserve_ticket;
/
