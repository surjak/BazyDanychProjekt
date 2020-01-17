CREATE VIEW CanceledConferences AS
SELECT C.ConferenceName,
       O.CompanyName,
       CIT.CityName,
       C2.CountryName,
       C.StartDate,
       C.EndDate
FROM Conferences C
         INNER JOIN Organizers O
                    ON C.OrganizerID = O.OrganizerID
         INNER JOIN Cities CIT
                    ON C.CityID = CIT.CityID
         INNER JOIN Countries C2
                    on CIT.CountryID = C2.CountryID
WHERE C.Canceled = 1
go

CREATE VIEW CanceledWorkshops AS
SELECT O.CompanyName,
       W.WorkshopName,
       W.Description,
       WD.StartTime,
       WD.EndTime
FROM WorkshopDetails WD
         INNER JOIN Workshops W
                    ON WD.WorkshopID = W.WorkshopID
         INNER JOIN Organizers O
                    ON W.OrganizerID = O.OrganizerID
WHERE WD.Canceled = 1
go

CREATE VIEW CountOfPaidReservationsFromCompaniesClients AS
SELECT Companies.CompanyName,
       (SELECT COUNT(ReservationID)
        FROM Reservations
        WHERE Clients.ClientID = Reservations.ClientID
          AND PaymentDate IS NOT NULL) as Count
FROM Clients
         INNER JOIN Reservations
                    ON Clients.ClientID = Reservations.ClientID
         INNER JOIN Companies
                    ON Clients.ClientID = Companies.ClientID
go

CREATE VIEW FreePlacesInConferences AS
SELECT Conferences.ConferenceID,
       Conferences.ConferenceName,
       ConferencesDays.Date,
       Conferences.Limit -
       ((SELECT ISNULL(SUM(NormalTickets), 0)
         FROM ReservationDays
         WHERE (ConferencesDays.ConferenceDayID = ConferenceDayID))
           +
        (SELECT ISNULL(SUM(StudentTickets), 0)
         FROM ReservationDays
         WHERE (ConferencesDays.ConferenceDayID = ConferenceDayID)))
           AS TicketsLeft
FROM Conferences
         INNER JOIN ConferencesDays
                    ON ConferencesDays.ConferenceID = Conferences.ConferenceID
go

CREATE VIEW FreePlacesInWorkshops AS
SELECT Workshops.WorkshopName,
       Workshops.Description,
       ConferencesDays.Date,
       WorkshopDetails.StartTime,
       WorkshopDetails.EndTime,
       WorkshopDetails.Limit - ((SELECT ISNULL(SUM(NormalTickets), 0)
                                 FROM WorkshopReservations
                                 WHERE (WorkshopDetails.WorkshopDetailsID =
                                        WorkshopDetailsID))
           +
                                (SELECT ISNULL(SUM(StudentTickets), 0)
                                 FROM WorkshopReservations
                                 WHERE (WorkshopDetails.WorkshopDetailsID =
                                        WorkshopDetailsID))) AS TicketsLeft
FROM WorkshopDetails
         INNER JOIN Workshops
                    ON Workshops.WorkshopID = WorkshopDetails.WorkshopID
         INNER JOIN ConferencesDays
                    ON ConferencesDays.ConferenceDayID =
                       WorkshopDetails.ConferenceDayID
go

CREATE VIEW ListConferencesInCities AS
SELECT Cities.CityName,
       COUNT(Conferences.ConferenceID) AS ConferencesCount
FROM Cities
         INNER JOIN Conferences
                    ON Cities.CityID = Conferences.CityID
GROUP BY Cities.CityName
go

CREATE VIEW ListConferencesInCountries AS
SELECT Countries.CountryName,
       COUNT(Conferences.ConferenceID) AS ConferencesCount
FROM Cities
         INNER JOIN Countries
                    ON Cities.CountryID = Countries.CountryID
         INNER JOIN Conferences
                    ON Cities.CityID = Conferences.CityID
GROUP BY Countries.CountryName
go

CREATE VIEW ListOfAttendeesIdentificators AS
SELECT Person.Firstname,
       Person.Lastname,
       { fn CONCAT(SUBSTRING(Person.Firstname, 0, 5),
                   SUBSTRING(Person.Lastname, 0, 5)) } AS Identificator
FROM Person
         INNER JOIN Attendees
                    ON Person.PersonID = Attendees.PersonID
         INNER JOIN ReservationDays
                    ON Attendees.ReservationDayID =
                       ReservationDays.ReservationDayID
go

CREATE VIEW PopularityOfConferences AS
SELECT TOP 2147483647 C.ConferenceID,
                      C.ConferenceName,
                      SUM(RD.NormalTickets) +
                      SUM(RD.StudentTickets) AS TicketsCount
FROM Conferences C
         INNER JOIN Reservations
                    ON C.ConferenceID = Reservations.ConferenceID
         INNER JOIN ReservationDays RD
                    ON Reservations.ReservationID =
                       RD.ReservationID
GROUP BY C.ConferenceID, C.ConferenceName
ORDER BY TicketsCount DESC
go

CREATE VIEW PopularityOfWorkshops AS
SELECT TOP 2147483647 W.WorkshopName,
                      W.Description,
                      SUM(WR.NormalTickets) +
                      SUM(WR.StudentTickets) AS TicketsCount
FROM Workshops W
         INNER JOIN WorkshopDetails WD
                    ON W.WorkshopID = WD.WorkshopID
         INNER JOIN WorkshopReservations WR
                    ON WD.WorkshopDetailsID =
                       WR.WorkshopDetailsID
GROUP BY W.WorkshopName, W.Description
ORDER BY TicketsCount DESC
go

CREATE VIEW UnpaidCompanyReservations AS
SELECT COM.CompanyName,
       C.ConferenceName,
       R.ReservationDate,
       C.StartDate,
       C.EndDate
FROM Conferences C
         INNER JOIN Reservations R
                    ON C.ConferenceID = R.ConferenceID
         INNER JOIN Companies COM
                    ON R.ClientID = COM.ClientID
WHERE R.PaymentDate IS NULL
go

CREATE VIEW UnpaidIndividualReservations AS
SELECT P.Firstname,
       P.Lastname,
       R.ReservationDate,
       C.ConferenceName,
       C.StartDate,
       C.EndDate
FROM Conferences C
         INNER JOIN Reservations R
                    ON C.ConferenceID = R.ConferenceID
         INNER JOIN IndividualClients IC
                    ON R.ClientID = IC.ClientID
         INNER JOIN Person P
                    ON IC.PersonID = P.PersonID
WHERE R.PaymentDate IS NULL
go

CREATE VIEW UnpaidReservationsThatShouldBePaidTomorrow AS
SELECT COM.CompanyName,
       C.ConferenceName,
       R.ReservationDate,
       C.StartDate,
       C.EndDate
FROM Reservations R
         INNER JOIN Clients
                    ON R.ClientID = Clients.ClientID
         INNER JOIN Companies COM
                    ON Clients.ClientID = COM.ClientID
         INNER JOIN Conferences C
                    ON R.ConferenceID = C.ConferenceID
WHERE R.PaymentDate IS NULL
  AND DATEDIFF(day, R.ReservationDate, GETDATE()) = 15
go


