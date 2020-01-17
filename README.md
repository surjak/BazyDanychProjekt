# Projekt z przedmiotu Bazy Danych na kierunku Informatyka - IET AGH

## System zarządzania konferencjami 

### Opis problemu
Projekt dotyczy systemu wspomagania działalności firmy organizującej konferencje: 

### Ogólne informacje  
Firma organizuje konferencje, które mogą być jedno- lub kilkudniowe. Klienci powinni móc rejestrować się na konferencje za pomocą systemu www.  Klientami mogą być zarówno indywidualne osoby jak i firmy, natomiast uczestnikami konferencji są osoby (firma nie musi podawać od razu przy rejestracji listy uczestników - może zarezerwować odpowiednią ilość miejsc na określone dni oraz na warsztaty, natomiast na 2 tygodnie przed rozpoczęciem musi te dane uzupełnić - a jeśli sama nie uzupełni do tego czasu, to pracownicy dzwonią do firmy i ustalają takie informacje). Każdy uczestnik konferencji otrzymuje identyfikator imienny (+ ew. informacja o firmie na nim). Dla konferencji kilkudniowych, uczestnicy mogą rejestrować się na dowolne z tych dni. 

### Warsztaty  
Ponadto z konferencją związane są warsztaty, na które uczestnicy także mogą się zarejestrować - muszą być jednak zarejestrowani tego dnia na konferencję, aby móc w nich uczestniczyć. Kilka warsztatów może trwać równocześnie, ale uczestnik nie może zarejestrować się na więcej niż jeden warsztat, który trwa w tym samym czasie. Jest także ograniczona ilość miejsc na każdy warsztat i na każdy dzień konferencji. Część warsztatów może być płatna, a część jest darmowa.  

### Opłaty  
Opłata za udział w konferencji zależy nie tylko od zarezerwowanych usług, ale także od terminu ich rezerwacji - jest kilka progów ceny (progi ceny dotyczą tylko udziału w konferencji, cena warsztatów jest stała) i im bliżej rozpoczęcia konferencji, tym cena jest wyższa (jest także zniżka procentowa dla studentów i w takim wypadku przy rezerwacji trzeba podać nr legitymacji studenckiej). Na zapłatę klienci mają tydzień od rezerwacji na konferencję - jeśli do tego czasu nie pojawi się opłata, rezerwacja jest anulowana. 
 
### Raporty  
Dla organizatora najbardziej istotne są listy osobowe uczestników na każdy dzień konferencji i na każdy warsztat, a także informacje o płatnościach klientów. Ponadto organizator chciałby mieć informację o klientach, którzy najczęściej korzystają z jego usług.  

### Specyfika firmy  
Firma organizuje średnio 2 konferencje w miesiącu, każda z nich trwa zwykle 2-3 dni, w tym średnio w każdym dniu są 4 warsztaty. Na każdą konferencję średnio rejestruje się 200 osób. Stworzona baza danych powinna zostać wypełniona w takim stopniu, aby odpowiadała 3-letniej działalności firmy. 
 
 
 
 
 
### Wymagane elementy w projekcie 
 propozycja funkcji realizowanych przez system - wraz z określeniem który użytkownik jakie funkcje może realizować (krótka lista) 
 projekt bazy danych  
 zdefiniowanie bazy danych 
 zdefiniowanie warunków integralności: wykorzystanie wartości domyślnych, ustawienie dopuszczalnych zakresów wartości, unikalność wartości w polach, czy dane pole może nie zostać wypełnione, złożone warunki integralnościowe 
 propozycja oraz zdefiniowanie operacji na danych (procedury składowane, triggery, funkcje) - powinny zostać zdefiniowane procedury składowane do wprowadzania danych (także do zmian konfiguracyjnych np. do zmiany ilości miejsc dla wybranego warsztatu). Należy stworzyć także funkcje zwracające istotne ilościowe informacje np. ile jest wolnych miejsc w danym warsztacie. Triggery należy wykorzystać do zapewnienia spójności oraz spełnienia przez system specyficznych wymagań klienta (np. określona ilość miejsc dla danego warsztatu) 
 propozycja oraz zdefiniowanie  struktury widoków ułatwiających dostęp do danych - widoki powinny prezentować dla użytkowników to, co ich najbardziej interesuje. Ponadto powinny zostać zdefiniowane widoki dla różnego typu raportów np. najpopularniejsze warsztaty 
 propozycja oraz zdefiniowanie indeksów 
 wygenerowanie przykładowych danych i wypełnienie nimi bazy - konieczny jest generator danych, który powinien wypełnić bazę w stopniu odpowiadającym 3-letniej działalności firmy 
 propozycja oraz określenie uprawnień do danych - należy zaproponować role oraz ich uprawnienia do operacji, widoków, procedur.. 
 
### Sprawozdanie powinno zawierać: 
 opis funkcji systemu wraz z informacją, co jaki użytkownik może wykonywać w systemie
 schemat bazy danych (w postaci diagramu) + opis poszczególnych tabel (nazwy pól, typ danych i znaczenie każdego pola, a także opis warunków integralności, jakie zostały zdefiniowane dla danego pola + kod generujący daną tabelę), informacja, do jakich pól stworzone są indeksy 
 spis widoków wraz z kodem, który je tworzy oraz informacją co one przedstawiają 
 spis procedur składowanych, triggerów, funkcji wraz z ich kodem i informacją co one robią 
 informacje odnośnie wygenerowanych danych (np. ile jest klientów)  określenie uprawnień do danych - opis ról wraz z przyporządkowaniem do jakich elementów dana rola powinna mieć uprawnienia 
