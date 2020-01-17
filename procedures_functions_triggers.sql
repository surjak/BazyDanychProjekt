CREATE FUNCTION [dbo].[Split](@sep char(1), @list varchar(3000))
    RETURNS table
        AS
        RETURN
            (
                WITH Pieces(pn, start, stop) AS (
                    SELECT 1, 1, CHARINDEX(@sep, @list)
                    UNION ALL
                    SELECT pn + 1, stop + 1, CHARINDEX(@sep, @list, stop + 1)
                    FROM Pieces
                    WHERE stop > 0
                )
                SELECT pn,
                       SUBSTRING(@list, start, CASE WHEN stop > 0 THEN stop - start ELSE 5000 END) AS s
                FROM Pieces
            )
go




CREATE FUNCTION fp_BestClients(
    @OrganizerID int
)
    RETURNS TABLE
        AS RETURN
            (
                SELECT ClientID,
                       (SELECT SUM(StudentTickets) + SUM(NormalTickets)
                        FROM dbo.[ReservationDays]
                                 INNER JOIN dbo.Reservations
                                            ON Reservations.ReservationID = [ReservationDays].ReservationID
                                 INNER JOIN dbo.Conferences
                                            ON Conferences.ConferenceID = Reservations.ConferenceID
                        WHERE OrganizerID = @OrganizerID
                          AND dbo.Clients.ClientID = dbo.Reservations.ClientID)
                           AS TOTAL
                FROM dbo.Clients
                WHERE (SELECT COUNT(*)
                       FROM dbo.[ReservationDays]
                                INNER JOIN dbo.Reservations
                                           ON Reservations.ReservationID = [ReservationDays].ReservationID
                                INNER JOIN dbo.Conferences
                                           ON Conferences.ConferenceID = Reservations.ConferenceID
                       WHERE OrganizerID = @OrganizerID
                         AND dbo.Clients.ClientID = dbo.Reservations.ClientID) > 0
                GROUP BY ClientID
            )
go

CREATE FUNCTION fp_ConferencesDaysWithFreePlaces(
    @OrganizerID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT DISTINCT ConferenceName, StartDate, EndDate
                FROM dbo.Conferences
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceID = Conferences.ConferenceID
                         INNER JOIN dbo.Reservations
                                    ON Reservations.ConferenceID = Conferences.ConferenceID
                         INNER JOIN dbo.[ReservationDays] ON [ReservationDays].ConferenceDayID =
                                                             [ConferencesDays].ConferenceDayID
                WHERE Limit >
                      (SELECT SUM(NormalTickets) + SUM(StudentTickets)
                       FROM dbo.[ReservationDays]
                       WHERE dbo.Conferences.OrganizerID = @OrganizerID)
            )
go

CREATE FUNCTION fp_GenerateInvoiceForReservationID(
    @ReservationID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT CONCAT('Konferencja: ', ConferenceName,
                              ',Data: ', Date, ' - ', NormalTickets, ' biletów normalnych')   AS Name,
                       dbo.sf_GetReservationNormalTicketPrice(@ReservationID) * NormalTickets AS COST
                FROM dbo.Reservations
                         INNER JOIN dbo.[ReservationDays]
                                    ON [ReservationDays].ReservationID = Reservations.ReservationID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceDayID =
                                                             [ReservationDays].ConferenceDayID
                WHERE Reservations.ReservationID = @ReservationID
                  AND NormalTickets > 0
                  AND EXISTS(SELECT *
                             FROM [dbo].[Reservations]
                             WHERE ReservationID = @ReservationID)
                UNION ALL
                SELECT CONCAT('Konferencja: ', ConferenceName, ',Data: ', Date, ' - ', StudentTickets,
                              ' biletów ulgowych')            AS Name,
                       dbo.sf_GetReservationNormalTicketPrice(@ReservationID) *
                       StudentTickets * (1 - StudentDiscount) AS COST
                FROM dbo.Reservations
                         INNER JOIN dbo.[ReservationDays]
                                    ON [ReservationDays].ReservationID = Reservations.ReservationID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceDayID =
                                                             [ReservationDays].ConferenceDayID
                WHERE Reservations.ReservationID = @ReservationID
                  AND StudentTickets > 0
                  AND EXISTS(SELECT *
                             FROM [dbo].[Reservations]
                             WHERE ReservationID = @ReservationID)
                UNION ALL
                SELECT CONCAT('Warsztat: ', WorkshopName,
                              ',Data: ', Date, ' - ', WorkshopReservations.NormalTickets,
                              ' biletów normalnych')                              AS Name,
                       WorkshopReservations.NormalTickets * WorkshopDetails.Price AS Cost
                FROM dbo.[WorkshopReservations]
                         INNER JOIN dbo.[WorkshopDetails] ON [WorkshopDetails].WorkshopDetailsID =
                                                             [WorkshopReservations].WorkshopDetailsID
                         join ReservationDays RD on WorkshopReservations.ReservationDayID = RD.ReservationDayID
                         join Reservations R2 on RD.ReservationID = R2.ReservationID
                         join Workshops W on WorkshopDetails.WorkshopID = W.WorkshopID
                         join ConferencesDays CD on RD.ConferenceDayID = CD.ConferenceDayID
                WHERE R2.ReservationID = @ReservationID
                  AND WorkshopReservations.NormalTickets > 0
                  AND EXISTS(SELECT *
                             FROM [dbo].[Reservations]
                             WHERE ReservationID = @ReservationID)
                UNION ALL
                SELECT CONCAT('Warsztat: ', WorkshopName,
                              ',Data: ', Date, ' - ', WorkshopReservations.StudentTickets, ' biletów ulgowych') AS Name,
                       WorkshopReservations.StudentTickets * WD.Price * (1 - StudentDiscount)                   AS Cost
                FROM dbo.[WorkshopReservations]
                         join ReservationDays D on WorkshopReservations.ReservationDayID = D.ReservationDayID
                         join Reservations R3 on D.ReservationID = R3.ReservationID
                         join Conferences C on R3.ConferenceID = C.ConferenceID
                         join ConferencesDays CD2 on C.ConferenceID = CD2.ConferenceID
                         join WorkshopDetails WD on CD2.ConferenceDayID = WD.ConferenceDayID
                         join Workshops W2 on WD.WorkshopID = W2.WorkshopID

                WHERE R3.ReservationID = @ReservationID
                  AND WorkshopReservations.StudentTickets > 0
                  AND EXISTS(SELECT *
                             FROM [dbo].[Reservations]
                             WHERE ReservationID = @ReservationID)
                UNION ALL
                SELECT 'Suma' AS NAME,
                       dbo.sf_GetReservationCost(@ReservationID)
                              AS COST
            )
go

CREATE FUNCTION fp_ListAttendeesInConference(
    @ConferenceID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT Firstname, Lastname
                FROM dbo.Clients
                         INNER JOIN dbo.Companies
                                    ON Companies.ClientID = Clients.ClientID
                         INNER JOIN dbo.Employees
                                    ON Employees.CompanyID = Companies.ClientID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = Employees.PersonID
                         INNER JOIN dbo.Reservations
                                    ON Reservations.ClientID = Clients.ClientID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                                        AND Conferences.ConferenceID = @ConferenceID
                WHERE dbo.Conferences.Canceled = 0
                UNION ALL
                SELECT Firstname, Lastname
                FROM dbo.Clients
                         INNER JOIN dbo.[IndividualClients] ON [IndividualClients].ClientID = Clients.ClientID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = [IndividualClients].PersonID
                         INNER JOIN dbo.Reservations
                                    ON Reservations.ClientID = Clients.ClientID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                                        AND Conferences.ConferenceID = @ConferenceID
                WHERE dbo.Conferences.Canceled = 0
            )
go

CREATE FUNCTION fp_ListAttendeesInConferenceDay(
    @ConferenceDayID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT Firstname, Lastname
                FROM dbo.Clients
                         INNER JOIN dbo.Companies ON Companies.ClientID = Clients.ClientID
                         INNER JOIN dbo.Employees
                                    ON Employees.CompanyID = Companies.ClientID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = Employees.PersonID
                         INNER JOIN dbo.Reservations
                                    ON Reservations.ClientID = Clients.ClientID
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceID = Reservations.ConferenceID
                    AND ConferenceDayID = @ConferenceDayID
                UNION ALL
                SELECT Firstname, Lastname
                FROM dbo.Clients
                         INNER JOIN dbo.[IndividualClients] ON [IndividualClients].ClientID = Clients.ClientID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = [IndividualClients].PersonID
                         INNER JOIN dbo.Reservations
                                    ON Reservations.ClientID = Clients.ClientID
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceID = Reservations.ConferenceID
                    AND ConferenceDayID = @ConferenceDayID
            )
go

CREATE FUNCTION fp_ListAttendeesInWorkshop(
    @WorkshopDetailsID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT Firstname, Lastname
                FROM dbo.[WorkshopAttendees]
                         INNER JOIN dbo.Attendees
                                    ON Attendees.AttendeeID = [WorkshopAttendees].AttendeeID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = Attendees.PersonID
                         INNER JOIN dbo.[WorkshopReservations] ON [WorkshopReservations].WorkshopReservationID =
                                                                  [WorkshopAttendees].WorkshopReservationID
                         INNER JOIN dbo.[WorkshopDetails] ON [WorkshopDetails].WorkshopDetailsID =
                                                             [WorkshopReservations].WorkshopDetailsID
                    AND [WorkshopDetails].WorkshopDetailsID = @WorkshopDetailsID
            )
go

CREATE FUNCTION fp_ListCompanyAttendeesInConference(
    @ConferenceID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT Firstname, Lastname
                FROM dbo.Clients
                         INNER JOIN dbo.Companies
                                    ON Companies.ClientID = Clients.ClientID
                         INNER JOIN dbo.Employees
                                    ON Employees.CompanyID = Companies.ClientID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = Employees.PersonID
                         INNER JOIN dbo.Reservations
                                    ON Reservations.ClientID = Clients.ClientID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                                        AND Conferences.ConferenceID = @ConferenceID
                WHERE dbo.Conferences.Canceled = 0
                  and Firstname is not null
                  and Lastname is not null
            )
go

CREATE FUNCTION [dbo].[fp_ListEmployeesInCompany](
    @CompanyID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT Firstname, Lastname
                FROM dbo.Employees
                         INNER JOIN dbo.Companies
                                    ON Companies.ClientID = Employees.CompanyID
                                        AND ClientID = @CompanyID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = Employees.PersonID
            )
go

CREATE FUNCTION fp_ListIndividualAttendeesInConference(
    @ConferenceID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT Firstname, Lastname
                FROM dbo.Clients
                         INNER JOIN dbo.[IndividualClients] ON [IndividualClients].ClientID = Clients.ClientID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = [IndividualClients].PersonID
                         INNER JOIN dbo.Reservations
                                    ON Reservations.ClientID = Clients.ClientID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                                        AND Conferences.ConferenceID = @ConferenceID
                WHERE dbo.Conferences.Canceled = 0
            )
go

CREATE FUNCTION fp_PrintActualReservationsForClient(
    @ClientID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT ReservationDate, PaymentDate, ConferenceName, StartDate
                FROM dbo.Reservations
                         INNER JOIN dbo.Clients
                                    ON Clients.ClientID = Reservations.ClientID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                WHERE (DATEDIFF(day, StartDate, dbo.Reservations.ReservationDate) < 0)
                  AND (DATEDIFF(DAY, StartDate, GETDATE()) < 0)
                  and Clients.ClientID = @ClientID
            )
go

CREATE FUNCTION fp_PrintActualReservationsForPerson(
    @PersonID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT ReservationDate,
                       PaymentDate,
                       ConferenceName,
                       StartDate
                FROM dbo.Reservations
                         INNER JOIN dbo.[ReservationDays] ON [ReservationDays].ReservationID =
                                                             Reservations.ReservationID
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceDayID =
                                                             [ReservationDays].ConferenceDayID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = [ConferencesDays].ConferenceID
                         INNER JOIN dbo.Attendees
                                    ON Attendees.ReservationDayID = [ReservationDays].ReservationDayID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = Attendees.PersonID
                                        AND Person.PersonID = @PersonID
                WHERE (DATEDIFF(day, StartDate, dbo.Reservations.ReservationDate) < 0)
                  AND (DATEDIFF(DAY, StartDate, GETDATE()) < 0)
            )
go

CREATE FUNCTION fp_PrintActualWorkshopsForPerson(
    @PersonID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT WorkshopName,
                       Description,
                       Date,
                       StartTime,
                       EndTime,
                       Address,
                       CityName
                FROM dbo.[WorkshopDetails]
                         INNER JOIN dbo.Workshops
                                    ON Workshops.WorkshopID = [WorkshopDetails].WorkshopID
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceDayID =
                                                             [WorkshopDetails].ConferenceDayID
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = [ConferencesDays].ConferenceID
                         INNER JOIN dbo.Cities ON Cities.CityID = Conferences.CityID
                         INNER JOIN dbo.[WorkshopReservations] ON [WorkshopReservations].WorkshopDetailsID =
                                                                  [WorkshopDetails].WorkshopDetailsID
                         INNER JOIN dbo.[ReservationDays] ON [ReservationDays].ConferenceDayID =
                                                             [ConferencesDays].ConferenceDayID
                         INNER JOIN dbo.Attendees
                                    ON Attendees.ReservationDayID =
                                       [ReservationDays].ReservationDayID
                         INNER JOIN dbo.Person
                                    ON Person.PersonID = Attendees.PersonID
                                        AND Attendees.PersonID = @PersonID
            )
go

CREATE FUNCTION [dbo].[fp_PrintNotPaidReservationsForClient](
    @ClientID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT ReservationID, ConferenceName, StartDate, EndDate
                FROM dbo.Reservations
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                         INNER JOIN dbo.Clients
                                    ON Clients.ClientID = Reservations.ClientID
                WHERE Clients.ClientID = @ClientID
                  AND PaymentDate IS NULL
            )
go

CREATE FUNCTION [dbo].[fp_PrintNotPaidReservationsForOrganizer](
    @Organizer int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT ReservationID, ConferenceName, StartDate, EndDate
                FROM dbo.Reservations
                         INNER JOIN dbo.Conferences
                                    ON Conferences.ConferenceID = Reservations.ConferenceID
                         INNER JOIN dbo.Organizers
                                    ON Organizers.OrganizerID = Conferences.OrganizerID
                WHERE Conferences.OrganizerID = @Organizer
                  AND PaymentDate IS NULL
            )
go

CREATE FUNCTION [dbo].[fp_WorkshopsWithFreePlaces](
    @OrganizerID int
)
    RETURNS TABLE
        AS
        RETURN
            (
                SELECT WorkshopDetailsID,
                       WorkshopName,
                       Description,
                       StartTime,
                       Date
                FROM dbo.[WorkshopDetails]
                         INNER JOIN dbo.Workshops
                                    ON Workshops.WorkshopID = [WorkshopDetails].WorkshopID
                         INNER JOIN dbo.[ConferencesDays] ON [ConferencesDays].ConferenceDayID =
                                                             [WorkshopDetails].ConferenceDayID
                WHERE Limit > (SELECT SUM(NormalTickets) + SUM(StudentTickets)
                               FROM dbo.[WorkshopReservations]
                               WHERE OrganizerID = @OrganizerID)
            )
go

CREATE FUNCTION [dbo].[sf_GetConferenceDayConferenceID](
    @ConferenceDayID int
)
    RETURNS int
AS
BEGIN
    RETURN (SELECT ConferenceID
            FROM [ConferencesDays]
            WHERE ConferenceDayID = @ConferenceDayID)
END
go

CREATE FUNCTION [dbo].[sf_GetConferenceDayFreePlaces](
    @conferenceDayID INT
)
    RETURNS INT
AS
BEGIN
    DECLARE @limit int =
        dbo.sf_GetConferenceLimit(dbo.sf_GetConferenceDayConferenceID(@conferenceDayID))
    DECLARE @used int =
        dbo.sf_GetConferenceDayUsedPlaces(@conferenceDayID)
    RETURN @limit - @used
END
go

CREATE FUNCTION [dbo].[sf_GetConferenceDayID](@conferenceID int,
                                              @date date)
    RETURNS int
AS
BEGIN
    RETURN (Select ConferenceDayID
            From [ConferencesDays]
            WHERE ConferenceID = @conferenceID
              AND Date = @date)
END
go

CREATE FUNCTION [dbo].[sf_GetConferenceDayUsedPlaces](
    @conferenceDayID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT SUM(NormalTickets) + SUM(StudentTickets)
                   FROM [ReservationDays]
                   Where ConferenceDayID = @conferenceDayID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetConferenceLimit](
    @conferenceID int)
    RETURNS int
AS
BEGIN
    RETURN (ISNULL((SELECT Limit
                    FROM Conferences
                    WHERE ConferenceID = @conferenceID), 0))
END
go

CREATE FUNCTION [dbo].[sf_GetConferenceOrganizerID](
    @conferenceID int
)
    RETURNS int
AS
BEGIN
    Return (
        Select OrganizerID
        From Conferences
        Where ConferenceID = @conferenceID)
END
go

CREATE FUNCTION [dbo].[sf_GetConferencePriceDiscount](@conferenceID int,
                                                      @date date)
    RETURNS decimal(3, 2)
AS
BEGIN
    RETURN ISNULL((SELECT PriceDiscount
                   FROM Prices
                   WHERE ConferenceID = @conferenceID
                     AND StartDate <= @date
                     AND @date <= EndDate), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetReservationCost](
    @reservationID int
)
    RETURNS int
AS

BEGIN
    DECLARE @normalprice MONEY =
        dbo.sf_GetReservationNormalTicketPrice(@reservationID)
    DECLARE @discount decimal(3, 2) =
        (SELECT C.StudentDiscount
         FROM Reservations as R
                  JOIN Conferences as C
                       ON C.ConferenceID = R.ConferenceID
         WHERE R.ReservationID = @reservationID)
    DECLARE @reservationCost MONEY =
        (Select Sum(NormalTickets) * @normalprice +
                Sum(StudentTickets) * @normalprice * (1 - @discount)
         From [ReservationDays]
         WHERE ReservationID = @reservationID)
    DECLARE @workshopCost MONEY =
        (Select sum(value)
         From (Select (Select SUM(WR.NormalTickets * WI.Price) +
                              SUM(WR.StudentTickets * (1 - @discount) * WI.Price)
                       FROM [WorkshopReservations] as WR
                                JOIN [WorkshopDetails] as WI
                                     ON WI.WorkshopDetailsID = WR.WorkshopDetailsID
                       WHERE WR.ReservationDayID = RD.ReservationDayID) as value
               From [ReservationDays] as RD
               WHERE RD.ReservationID = @reservationID) src)
    RETURN ISNULL(@reservationCost, 0) + ISNULL(@workshopCost, 0)
END
go

CREATE FUNCTION [dbo].[sf_GetReservationDayNormal](
    @reservationDayID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT NormalTickets
                   FROM [ReservationDays]
                   WHERE ReservationDayID = @reservationDayID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetReservationDayNormalUsed](
    @reservationDayID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT Count(PersonID)
                   FROM Attendees
                   WHERE ReservationDayID = @reservationDayID) -
                  dbo.sf_GetReservationDayStudentUsed(@reservationDayID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetReservationDayStudent](
    @reservationDayID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT StudentTickets
                   FROM [ReservationDays]
                   WHERE ReservationDayID = @reservationDayID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetReservationDayStudentUsed](
    @reservationDayID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT Count(A.PersonID)
                   FROM Attendees as A
                            JOIN Students as S
                                 ON S.AttendeeID = A.AttendeeID
                   WHERE A.ReservationDayID = @reservationDayID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetReservationNormalTicketPrice](
    @reservationID INT
)
    RETURNS MONEY
AS
BEGIN
    DECLARE @normalPrice MONEY =
        (SELECT C.Price *
                (1 - dbo.sf_GetConferencePriceDiscount(C.ConferenceID, R.ReservationDate))
         FROM Reservations as R
                  JOIN Conferences as C
                       ON C.ConferenceID = R.ConferenceID
         WHERE R.ReservationID = @reservationID)
    RETURN ISNULL(@normalprice, 0
        )
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopDetailsFreePlaces](
    @workshopDetailsID INT
)
    RETURNS INT
AS
BEGIN
    RETURN (dbo.sf_GetWorkshopDetailsLimit(@workshopDetailsID) -
            dbo.sf_GetWorkshopDetailsUsedPlaces(@workshopDetailsID))
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopDetailsLimit](
    @workshopInstanceID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT Limit
                   FROM [WorkshopDetails]
                   WHERE WorkshopDetailsID = @workshopInstanceID),
                  0)
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopDetailsUsedPlaces](
    @workshopDetailsID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT SUM(NormalTickets) + SUM(StudentTickets)
                   FROM [WorkshopReservations]
                   Where WorkshopDetailsID = @workshopDetailsID),
                  0)
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopOrganizerID](
    @workshopID int
)
    RETURNS int
AS
BEGIN
    Return (
        Select OrganizerID
        From Workshops
        Where WorkshopID = @workshopID)
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopReservationNormal](
    @workshopReservationID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT NormalTickets
                   FROM [WorkshopReservations]
                   WHERE WorkshopReservationID = @workshopReservationID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopReservationNormalUsed](
    @workshopReservationID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT Count(WP.AttendeeID)
                   FROM [WorkshopReservations] as WR
                            JOIN [WorkshopAttendees] as WP
                                 ON WP.WorkshopReservationID = WR.WorkshopReservationID
                   WHERE WP.WorkshopReservationID = @workshopReservationID)
                      - dbo.sf_GetWorkshopReservationStudentUsed(@workshopReservationID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopReservationStudent](
    @workshopReservationID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT StudentTickets
                   FROM [WorkshopReservations]
                   WHERE WorkshopReservationID = @workshopReservationID), 0)
END
go

CREATE FUNCTION [dbo].[sf_GetWorkshopReservationStudentUsed](
    @workshopReservationID int
)
    RETURNS int
AS
BEGIN
    RETURN ISNULL((SELECT Count(P.PersonID)
                   FROM [WorkshopReservations] as WR
                            JOIN [WorkshopAttendees] as WP
                                 ON WP.WorkshopReservationID = WR.WorkshopReservationID
                            JOIN Attendees as P
                                 ON WP.AttendeeID = P.AttendeeID
                            JOIN Students as S
                                 ON S.AttendeeID = P.AttendeeID
                   WHERE WP.WorkshopReservationID = @workshopReservationID), 0)
END
go

CREATE PROCEDURE [dbo].[sp_AddParticipant] @reservationDayID int,
                                           @personID int,
                                           @studentCardID char(10) = NULL,
                                           @participantID int out
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_Participant
            IF ((SELECT ClientID
                 FROM [ReservationDays] as RD
                          JOIN Reservations as R
                               ON R.ReservationID = RD.ReservationID
                 WHERE RD.ReservationDayID = @reservationDayID) <>
                (SELECT CompanyID
                 FROM Employees
                 WHERE PersonID = @personID))
                BEGIN
                    ;
                    THROW 52000,
                        'Pracownik nie należy do klienta do ktorego nalezy rezerwacja', 1;
                END
            IF (SELECT Count(personID)
                FROM Attendees as P
                         JOIN [ReservationDays] as RD
                              On RD.ReservationDayID = P.ReservationDayID
                WHERE P.PersonID = @personID
                  and RD.ReservationDayID = @reservationDayID) > 0
                BEGIN
                    ;
                    THROW 52000,
                        'Pracownik jest już przypisany do rezerwacji', 1;
                END
            IF (@studentCardID is not null)
                BEGIN
                    IF (dbo.sf_GetReservationDayStudent
                            (@reservationDayID) -
                        dbo.sf_GetReservationDayStudentUsed
                            (@reservationDayID) < 1)
                        BEGIN
                            ;
                            THROW 52000,
                                'Brak wolnych miejsc studenckich
                                w rezerwacji', 1;
                        END
                    INSERT INTO Attendees(PersonID, ReservationDayID)
                    VALUES (@personID, @reservationDayID)
                    SET @participantID = @@IDENTITY
                    INSERT INTO Students(AttendeeID, StudentCardID)
                    VALUES (@participantID, @studentCardID)
                END
            ELSE
                BEGIN
                    IF (dbo.sf_GetReservationDayNormal
                            (@reservationDayID) -
                        dbo.sf_GetReservationDayNormalUsed(@reservationDayID) < 1)
                        BEGIN
                            ;
                            THROW 52000,
                                'Brak wolnych miejsc normalnych w rezerwacji', 1;
                        END
                    INSERT INTO Attendees(PersonID, ReservationDayID)
                    VALUES (@personID, @reservationDayID)
                    SET @participantID = @@IDENTITY
                END
        COMMIT TRAN ADD_Participant
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_Participant
        DECLARE @msg NVARCHAR(2048) = 'Bład dodania uczestnika:'
            +
                                      CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddCompanyClient] @companyName varchar(255),
                                             @nip char(10),
                                             @contactName varchar(255),
                                             @phone varchar(255),
                                             @email varchar(255),
                                             @address varchar(255) = NULL,
                                             @cityName varchar(255) = NULL,
                                             @countryName varchar(255) = NULL,
                                             @postalCode varchar(255) = NULL,
                                             @clientID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_COMPANY_CLIENT
            EXEC sp_InsertClient
                 @email,
                 @address,
                 @cityName,
                 @countryName,
                 @postalCode,
                 @clientID = @clientID OUTPUT

            INSERT INTO Companies(ClientID, CompanyName, NIP,
                                  ContactName, Phone)
            VALUES (@clientID,
                    @companyName,
                    @nip,
                    @contactName,
                    @phone);
        COMMIT TRAN ADD_COMPANY_CLIENT
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_COMPANY_CLIENT
        DECLARE @msg NVARCHAR(2048) = 'Blad dodania firmy jako klienta:' +
                                      CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddConference] @organizerID int,
                                          @conferenceName varchar(255),
                                          @studentDiscount decimal(3, 2) = 0,
                                          @address varchar(255),
                                          @cityName varchar(255),
                                          @countryName varchar(255),
                                          @postalCode varchar(255),
                                          @startDate date,
                                          @endDate date,
                                          @limit int,
                                          @price money,
                                          @conferenceID int out
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_Conference
            IF (@startDate < GETDATE())
                BEGIN
                    ;
                    THROW 52000,
                        'Data startu konferencji jest wcześniejsza niż obecna data', 1;
                END
            DECLARE @cityID int
            EXEC sp_FindCity
                 @cityName,
                 @countryName,
                 @cityID = @cityID out
            INSERT INTO Conferences(OrganizerID,
                                    ConferenceName,
                                    StudentDiscount,
                                    Address,
                                    CityID,
                                    PostalCode,
                                    StartDate,
                                    EndDate,
                                    Limit,
                                    Price)
            VALUES (@organizerID,
                    @conferenceName,
                    @studentDiscount,
                    @address,
                    @cityID,
                    @postalCode,
                    @startDate,
                    @endDate,
                    @limit,
                    @price);
            SET @conferenceID = @@IDENTITY;
            --             DECLARE @i date = @startDate
--             WHILE @i <= @endDate
--                 BEGIN
--                     INSERT INTO [ConferencesDays](ConferenceID, Date)
--                     VALUES (@conferenceID, @i)
--                     SET @i = DATEADD(d, 1, @i)
--                 END
        COMMIT TRAN ADD_Conference
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_Conference
        DECLARE @msg NVARCHAR(2048) =
                'Bład tworzenia konferencji:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddEmployee] @companyID INT,
                                        @firstname varchar(255) = NULL,
                                        @lastname varchar(255) = NULL,
                                        @phone varchar(255) = NULL,
                                        @personID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_Employee
            EXEC [dbo].sp_InsertPerson
                 @firstname,
                 @lastname,
                 @phone,
                 @personID = @personID OUTPUT
            INSERT INTO Employees (PersonID, CompanyID)
            VALUES (@personID, @companyID);
        COMMIT TRAN ADD_Employee
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_Employee
        DECLARE @msg NVARCHAR(2048) =
                'Bład dodania pracownika:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddIndividualClient] @firstname varchar(255),
                                                @lastname varchar(255),
                                                @phone varchar(255),
                                                @email varchar(255),
                                                @address varchar(255) = NULL,
                                                @cityName varchar(255) = NULL,
                                                @countryName varchar(255) = NULL,
                                                @postalCode varchar(255) = NULL,
                                                @clientID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_INDIVIDUAL_CLIENT
            DECLARE @personID int
            EXEC sp_InsertClient
                 @email,
                 @address,
                 @cityName,
                 @countryName,
                 @postalCode,
                 @clientID = @clientID OUTPUT

            EXEC sp_InsertPerson
                 @firstname,
                 @lastname,
                 @phone,
                 @personID = @personID OUTPUT

            INSERT INTO [IndividualClients] (ClientID, PersonID)
            VALUES (@clientID,
                    @personID);

        COMMIT TRAN ADD_INDIVIDUAL_CLIENT
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_INDIVIDUAL_CLIENT
        DECLARE @msg NVARCHAR(2048) =
                'BLad dodania klienta indiwidualnego:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddOrganizer] @companyName varchar(255),
                                         @nip char(10),
                                         @contactName varchar(255),
                                         @email varchar(255),
                                         @phone varchar(255),
                                         @address varchar(255) = NULL,
                                         @cityName varchar(255) = NULL,
                                         @countryName varchar(255) = NULL,
                                         @postalCode varchar(255) = NULL,
                                         @organizerID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_Organizer
            DECLARE @cityID int = NULL

            EXEC sp_FindCity
                 @cityName,
                 @countryName,
                 @cityID = @cityID OUTPUT
            INSERT INTO Organizers(CompanyName, NIP,
                                   ContactName, Email, Phone,
                                   Address, PostalCode, CityID)
            VALUES (@companyName,
                    @nip,
                    @contactName,
                    @email,
                    @phone,
                    @address,
                    @postalCode,
                    @cityID);
            SET @organizerID = @@IDENTITY
        COMMIT TRAN ADD_Organizer
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_Organizer
        DECLARE @msg NVARCHAR(2048) =
                'Bład dodania organizatora do bazy:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddPrice] @conferenceID int,
                                     @startDate date,
                                     @endDate date,
                                     @priceDiscount decimal(3, 2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_PRICE_TO_CONFERENCE
            IF (Convert(date, getdate()) > @startDate)
                BEGIN
                    ;
                    THROW 52000,
                        'Data produ cenowego juz byla', 1;
                END
            IF (@endDate >= (SELECT StartDate
                             FROM Conferences
                             WHERE ConferenceID = @conferenceID))
                BEGIN
                    ;
                    THROW 52000,
                        'Progi cenowe nie mogą kończyć sie po rozpoczęciu konferencji', 1;
                END
            IF (0 < (SELECT Count(PriceID)
                     FROM Prices
                     WHERE ConferenceID = @conferenceID
                       and ((StartDate <= @endDate and @endDate <= EndDate) or
                            (StartDate <= @startDate and @startDate <= EndDate))))
                BEGIN
                    ;
                    THROW 52000,
                        'Konferencja ma juz prog cenowy pokrywajacy sie z tym okresem czasu', 1;
                END
            INSERT INTO Prices(ConferenceID, StartDate, EndDate,
                               PriceDiscount)
            VALUES (@conferenceID,
                    @startDate,
                    @endDate,
                    @priceDiscount)
        COMMIT TRAN ADD_PRICE_TO_CONFERENCE
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_PRICE_TO_CONFERENCE
        DECLARE @msg NVARCHAR(2048) =
                'Bład dodania progu cenowego do konferencji:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddReservation] @conferenceID int,
                                           @clientID int,
                                           @reservationID int out
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_RESERVATION
            DECLARE @date date = GETDATE()
            IF ((SELECT Count(ConferenceID)
                 FROM Conferences
                 WHERE ConferenceID = @conferenceID) = 0)
                BEGIN
                    ;
                    THROW 52000,
                        'Podana konferencja nie istnieje', 1;
                END
            IF ((SELECT Count(ReservationID)
                 FROM Reservations
                 WHERE ClientID = @clientID
                   and ConferenceID = @conferenceID) > 0)
                BEGIN
                    ;
                    THROW 52000,
                        'Podany klient już posiada rezerwacje na dana konferencje', 1;
                END
            IF ((SELECT StartDate
                 FROM Conferences
                 WHERE ConferenceID = @conferenceID) <= @date)
                BEGIN
                    ;
                    THROW 52000,
                        'Niestety nie mozna juz dokonywac rezerwacji na podana konferencje', 1;
                END
            IF ((SELECT Canceled
                 FROM Conferences
                 WHERE ConferenceID = @conferenceID) = 1)
                BEGIN
                    ;
                    THROW 52000,
                        'Konferencja zostala anulowana',
                        1;
                END
            INSERT INTO Reservations(ConferenceID, ClientID,
                                     ReservationDate)
            VALUES (@conferenceID, @clientID, @date)
            SET @reservationID = @@IDENTITY
        COMMIT TRAN ADD_RESERVATION
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_RESERVATION
        DECLARE @msg NVARCHAR(2048) =
                'Bład dodania rezerwacji:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddReservationDay] @reservationID int,
                                              @conferenceDayID int,
                                              @normalTickets int = 0,
                                              @studentTickets int = 0,
                                              @studentCardIDs varchar(3000) = null,
                                              @reservationDayID int out
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_ReservationDay
            IF (dbo.sf_GetConferenceDayConferenceID(@conferenceDayID) <> (Select ConferenceID
                                                                          FROM Reservations
                                                                          WHERE ReservationID = @reservationID))
                BEGIN
                    ;
                    THROW 52000,
                        'Rezerwacja jest na inna konferencje', 1;
                END
            IF ((SELECT PaymentDate
                 FROM Reservations
                 WHERE ReservationID = @reservationID) is not null)
                BEGIN
                    ;
                    THROW 52000,'Rezerwacja została już opłacona', 1;
                END
            IF (@normalTickets + @studentTickets = 0)
                BEGIN
                    ;
                    THROW 52000,
                        'Trzeba rezerwowac przynajmniej jedno miejsce', 1;
                END
            IF ((SELECT count(ReservationID)
                 FROM [ReservationDays]
                 WHERE ReservationID = @reservationID
                   AND ConferenceDayID = @conferenceDayID) = 1)
                BEGIN
                    ;
                    THROW 52000,
                        'Klient posiada już rezerwacje na dany dzień konferencji', 1;
                END
            IF ((SELECT Canceled
                 FROM [ConferencesDays]
                 WHERE ConferenceDayID = @conferenceDayID) =
                1)
                BEGIN
                    ;
                    THROW 52000,
                        'Ten dzien konferencji zostal anulowany', 1;
                END
            IF (dbo.sf_GetConferenceDayFreePlaces
                    (@conferenceDayID) < @normalTickets + @studentTickets)
                BEGIN
                    ;
                    THROW 52000,
                        'Nie ma wystarczajacej ilosci wolnych miejsc', 1;
                END
            INSERT INTO [ReservationDays](ReservationID,
                                          ConferenceDayID,
                                          NormalTickets,
                                          StudentTickets)
            VALUES (@reservationID,
                    @conferenceDayID,
                    @normalTickets,
                    @studentTickets)
            SET @reservationDayID = @@IDENTITY
            --             if @studentCardIDs is null and @studentTickets > 0
--                 begin
--                     ;
--                     THROW 52000,
--                         'Nie podano ID studentow', 1;
--                 end

            if @studentCardIDs is not null
                begin
                    if (select count(*) from Split(' ', @studentCardIDs)) != @studentTickets
                        begin
                            ;
                            THROW 52000,
                                'Liczba student IDs jest rozna od liczby biletow studenckich', 1;
                        end
                    Select *
                    Into #Temp
                    From Split(' ', @studentCardIDs)

                    Declare @Id int
                    declare @scID varchar(100)

                    While (Select Count(*) From #Temp) > 0
                        Begin

                            Select Top 1 @Id = pn, @scID = s From #Temp


                            declare @personId int
                            declare @companyID int
                            set @companyID = (select ClientID from Reservations where ReservationID = @reservationID)

                            exec sp_AddEmployee @companyID, null, null, null, @personId out
                            exec sp_AddAttendee @reservationDayID, @personId, @scID, null

                            Delete #Temp Where pn = @Id

                        End
                end
        COMMIT TRAN ADD_ReservationDay
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_ReservationDay
        DECLARE @msg NVARCHAR(2048) =
            'Bład dodania rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddReservationDayIndividual] @clientID int,
                                                        @reservationID int,
                                                        @conferenceDayID int,
                                                        @studentCardID char(10) = null,
                                                        @reservationDayID int out
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN ADD_ReservationDayIndividual
            DECLARE @personID int =
                (SELECT top 1 IC.PersonID
                 FROM Reservations as R
                          JOIN [IndividualClients] as IC
                               ON IC.ClientID = R.ClientID
                 where IC.ClientID = @clientID)
            IF (@personID is null)
                BEGIN
                    ;THROW 52000,'Nie istnieje klient o takim ID', 1;
                END
            DECLARE @normal int = 1
            DECLARE @student int = 0
            IF (@studentCardID is not null)
                BEGIN
                    SET @normal = 0
                    SET @student = 1
                END
            EXEC sp_AddReservationDay
                 @reservationID,
                 @conferenceDayID,
                 @normal,
                 @student,
                 null,
                 @reservationDayID = @reservationDayID out
            INSERT INTO Attendees(PersonID, ReservationDayID)
            VALUES (@personID, @reservationDayID)
            DECLARE @attendeeID int = @@IDENTITY
            IF (@studentCardID is not null)
                BEGIN
                    INSERT INTO Students(AttendeeID, StudentCardID)
                    VALUES (@attendeeID, @studentCardID)
                END
        COMMIT TRAN ADD_ReservationDayIndividual
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_ReservationDayIndividual
        DECLARE @msg NVARCHAR(2048) =
                'Bład dodania rezerwacji inwidualnej:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddReservationWorkshop] @reservationDayID int,
                                                   @workshopDetailsID int,
                                                   @normalTickets int = 0,
                                                   @studentTickets int = 0,
                                                   @workshopReservationID int out
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_WorkshopReservation
            IF (@normalTickets + @studentTickets = 0)
                BEGIN
                    THROW 52000,
                        'Trzeba rezerwowac przynajmniej jedno mie
                        jsce', 1;
                END
            IF ((SELECT R.PaymentDate
                 FROM Reservations as R
                          JOIN [ReservationDays] as RD
                               ON RD.ReservationID = R.ReservationID
                 WHERE RD.ReservationDayID = @reservationDayID) is not null)
                BEGIN
                    THROW 52000,
                        'Rezerwacja została już opłacona', 1;
                END
            IF ((SELECT count(ReservationDayID)
                 FROM [WorkshopReservations]
                 WHERE ReservationDayID = @reservationDayID
                   and @workshopDetailsID = WorkshopDetailsID)
                > 0)
                BEGIN
                    THROW 52000,
                        'Klient posiada już rezerwacje na dany warsztat', 1;
                END
            IF ((SELECT ConferenceDayID
                 FROM [WorkshopDetails]
                 WHERE WorkshopDetailsID = @workshopDetailsID) <>
                (SELECT ConferenceDayID
                 FROM [ReservationDays]
                 WHERE ReservationDayID = @reservationDayID))
                BEGIN
                    ;
                    THROW 52000,
                        'Rezerwacja i warsztat odwołują sie do innego dnia konferencji', 1;
                END
            IF ((SELECT Canceled
                 FROM [WorkshopDetails]
                 WHERE WorkshopDetailsID = @workshopDetailsID) = 1)
                BEGIN
                    THROW 52000,
                        'Ten warsztat zostal anulowany',
                        1;
                END
            IF (dbo.sf_GetWorkshopDetailsFreePlaces(@workshopDetailsID) < @normalTickets + @studentTickets)
                BEGIN
                    ;
                    THROW 52000,
                        'Niestety nie ma wystarczajacej ilosci wolnych miejsc', 1;
                END
            IF (dbo.sf_GetReservationDayNormal(@reservationDayID) < @normalTickets
                or dbo.sf_GetReservationDayStudent(@reservationDayID) < @studentTickets)
                BEGIN
                    ;
                    THROW 52000,
                        'Nie mozna rezerwowac wiekszej ilosci miejsc niz w rezerwacji na dzien konferencji', 1;
                END
            INSERT INTO [WorkshopReservations](WorkshopDetailsID,
                                               NormalTickets,
                                               StudentTickets,
                                               ReservationDayID)
            VALUES (@workshopDetailsID,
                    @normalTickets,
                    @studentTickets,
                    @reservationDayID)
            SET @workshopReservationID = @@IDENTITY
        COMMIT TRAN ADD_WorkshopReservation
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_WorkshopReservation
        DECLARE @msg NVARCHAR(2048) =
            'Bład dodania rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddReservationWorkshopIndividual] @reservationDayID int,
                                                             @workshopDetailsID int,
                                                             @workshopReservationID int out
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN ADD_ReservationWorkshopInd
            DECLARE @attendeeID int =
                (SELECT AttendeeID
                 FROM Attendees
                 WHERE ReservationDayID = @reservationDayID)

            DECLARE @normal int =
                dbo.sf_GetReservationDayNormal(@reservationDayID)
            DECLARE @student int =
                dbo.sf_GetReservationDayStudent(@reservationDayID)
            EXEC sp_AddReservationWorkshop
                 @reservationDayID,
                 @workshopDetailsID,
                 @normal,
                 @student,
                 @workshopReservationID = @workshopReservationID out
            EXEC sp_AddWorkshopAttendee
                 @workshopReservationID,
                 @attendeeID
        COMMIT TRAN ADD_ReservationWorkshopInd
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_ReservationWorkshopInd
        DECLARE @msg NVARCHAR(2048) =
                'Bład dodania rezerwacji inwidualnej:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddWorkshop] @organizerID int,
                                        @workshopName varchar(255),
                                        @workshopDescription varchar(255),
                                        @workshopID int out
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Workshops(OrganizerID,
                          WorkshopName, Description)
    VALUES (@organizerID,
            @workshopName,
            @workshopDescription)
    SET @workshopID = @@IDENTITY
END
go

CREATE PROCEDURE [dbo].[sp_AddWorkshopAttendee] @workshopReservationID int,
                                                @attendeeID int
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN ADD_WorkshopAttendee
            print @workshopReservationID
            print @attendeeID
            IF (SELECT Count(RD.ReservationDayID)
                FROM [ReservationDays] as RD
                         JOIN Attendees as P
                              ON P.ReservationDayID = RD.ReservationDayID
                         JOIN [WorkshopReservations] as WR
                              ON WR.ReservationDayID = RD.ReservationDayID
                where WR.WorkshopReservationID = @workshopReservationID
                  and P.AttendeeID = @attendeeID) = 0
                BEGIN
                    print '1';
                    THROW 52000,'Uczestnik jest zapisany na inny dzien konferencji niż rezerwacja warsztatu', 1;
                END
            print '12'
            DECLARE @workshopDetailsID INT = (SELECT WorkshopDetailsID
                                              FROM [WorkshopReservations]
                                              WHERE workshopReservationID = @workshopReservationID)
            DECLARE @ConferenceDayID INT = (SELECT ConferenceDayID
                                            FROM [WorkshopDetails]
                                            WHERE WorkshopDetailsID = @workshopDetailsID)
            DECLARE @startTime time = (SELECT StartTime
                                       FROM [WorkshopDetails]
                                       WHERE WorkshopDetailsID = @workshopDetailsID)
            DECLARE @endTime time = (SELECT EndTime
                                     FROM [WorkshopDetails]
                                     WHERE WorkshopDetailsID = @workshopDetailsID)
            IF ((SELECT COUNT(WP.AttendeeID)
                 FROM [WorkshopDetails] as WI
                          JOIN [WorkshopReservations] as WR
                               ON WR.WorkshopDetailsID = WI.WorkshopDetailsID
                          JOIN [WorkshopAttendees] as WP
                               ON WP.WorkshopReservationID = WR.WorkshopReservationID
                                   and WP.AttendeeID = @attendeeID
                 WHERE ((WI.StartTime <= @startTime and @startTime <= WI.EndTime) or
                        (WI.StartTime <= @endTime and @endTime <= WI.EndTime))
                   and WI.ConferenceDayID = @ConferenceDayID) > 0)
                BEGIN
                    print '2';THROW 52000,'Uczestnik jest zapisany na inny warsztat w tym czasie', 1;
                END
            IF ((Select Count(AttendeeID)
                 FROM Students
                 WHERE AttendeeID = @attendeeID) > 0)
                BEGIN
                    IF (dbo.sf_GetWorkshopReservationStudent(@workshopReservationID) -
                        dbo.sf_GetWorkshopReservationStudentUsed(@workshopReservationID) < 1)
                        BEGIN
                            print '3';THROW 52000,'Brak wolnych miejsc studenckich w rezerwacji', 1;
                        END
                END
            ELSE
                BEGIN
                    IF (dbo.sf_GetWorkshopReservationNormal(@workshopReservationID) -
                        dbo.sf_GetWorkshopReservationNormalUsed(@workshopReservationID) < 1)
                        BEGIN
                            print '4';THROW 52000,'Brak wolnych miejsc normalnych w rezerwacji', 1;
                        END
                END
            INSERT INTO [WorkshopAttendees] (WorkshopReservationID, AttendeeID)
            VALUES (@workshopReservationID, @attendeeID)
        COMMIT TRAN ADD_WorkshopAttendee
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN ADD_WorkshopAttendee
        DECLARE @msg NVARCHAR(2048) = 'Bład dodania uczestnika do warsztatu:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_AddWorkshopDetails] @workshopID int,
                                               @conferenceID int,
                                               @date date,
                                               @startTime time(7),
                                               @endTime time(7),
                                               @limit int,
                                               @price money = 0,
                                               @workshopInstanceID int out
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN Add_WorkshopDetails
            IF (@date < GETDATE())
                BEGIN
                    ;
                    THROW 52000,'Data warsztatu jest niepoprawna', 1;
                END
            IF (dbo.sf_GetWorkshopOrganizerID(@workshopID) <>
                dbo.sf_GetConferenceOrganizerID(@conferenceID))
                BEGIN
                    ;
                    THROW 52000,'Warsztat i konfrenceja naleza do innych organizatorow', 1;
                END
            IF (dbo.sf_GetConferenceLimit(@conferenceID) < @limit)
                BEGIN
                    ;
                    THROW 52000,'Limit miejsc nie może być wieksza od liczby miejsc na konferencje', 1;
                END
            DECLARE @conferenceDayID int = dbo.sf_GetConferenceDayID(@conferenceID, @date)
            IF (@conferenceDayID is null)
                BEGIN
                    ;
                    THROW 52000,'Konferencja nie odbywa sie danego dnia', 1;
                END
            INSERT INTO [WorkshopDetails](WorkshopID,
                                          ConferenceDayID,
                                          StartTime,
                                          EndTime,
                                          Limit,
                                          Price, Canceled)
            VALUES (@workshopID,
                    @conferenceDayID,
                    @startTime,
                    @endTime,
                    @limit,
                    @price, '')
            SET @workshopInstanceID = @@IDENTITY
        COMMIT TRAN Add_WorkshopDetails
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN Add_WorkshopDetails
        DECLARE @msg NVARCHAR(2048) =
                'Bład dodania warsztatu do konferencji:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_CancelConference] @conferenceID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN CancelConference
            IF ((Select Canceled
                 FROM Conferences
                 WHERE conferenceID = @conferenceID) != 0)
                BEGIN
                    ;THROW 52000,'Konferencja została wczesniej anulowana', 1;
                END

            UPDATE Conferences
            SET Canceled = 1
            WHERE conferenceID = @conferenceID

            DELETE Reservations
            WHERE conferenceID = @conferenceID
              and PaymentDate is null

            UPDATE ConferencesDays
            set Canceled = 1
            where ConferenceID = @conferenceID

            UPDATE WorkshopDetails
            set Canceled = 1
            where ConferenceDayID in
                  (select ConferencesDays.ConferenceDayID from ConferencesDays where ConferenceID = @conferenceID)
        COMMIT TRAN CancelConference
    END TRY BEGIN CATCH
        ROLLBACK TRAN CancelConference
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany konferencji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_CancelConferenceDay] @conferenceDayID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN CancelConferenceDay
            IF ((Select Canceled
                 FROM [ConferencesDays]
                 WHERE conferenceDayID = @conferenceDayID) != 0)
                BEGIN
                    ;THROW 52000,'Dzien został wczesniej anulowany', 1;
                END

            UPDATE [ConferencesDays]
            SET Canceled = 1
            WHERE conferenceDayID = @conferenceDayID

            DELETE RD
            FROM [ReservationDays] as RD
                     JOIN Reservations as R
                          ON R.ReservationID = RD.ReservationID
            WHERE RD.conferenceDayID = @conferenceDayID
              and R.PaymentDate is null
        COMMIT TRAN CancelConferenceDay
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN CancelConferenceDay
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany konferencji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_CancelWorkshop] @WorkshopDetailsID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN CancelWorkshop
            IF ((Select Canceled
                 FROM [WorkshopDetails]
                 WHERE WorkshopDetailsID = @WorkshopDetailsID) != 0)
                BEGIN
                    ;THROW 52000,'Warsztat już anulowany', 1;
                END

            UPDATE [WorkshopDetails]
            SET Canceled = 1
            WHERE WorkshopDetailsID = @WorkshopDetailsID

            DELETE WA
            FROM [WorkshopAttendees] as WA
                     JOIN [WorkshopReservations] as WR
                          ON WA.WorkshopReservationID = WR.WorkshopReservationID
                     JOIN [ReservationDays] as RD
                          ON RD.ReservationDayID = WR.ReservationDayID
                     JOIN Reservations as R
                          ON R.ReservationID = RD.ReservationID
            WHERE WR.WorkshopDetailsID = @WorkshopDetailsID
              and R.PaymentDate is null

            DELETE WR
            FROM [WorkshopReservations] as WR
                     JOIN [ReservationDays] as RD
                          ON RD.ReservationDayID = WR.ReservationDayID
                     JOIN Reservations as R
                          ON R.ReservationID = RD.ReservationID
            WHERE WR.WorkshopDetailsID = @WorkshopDetailsID
              and R.PaymentDate is null
        COMMIT TRAN CancelWorkshop
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN CancelWorkshop
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany warsztatu:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_FindCity] @cityName varchar(255),
                                     @countryName varchar(255),
                                     @cityID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN FIND_CITY_BY_NAME
            SET @cityID = null
            IF ((@cityName is not null and @countryName is null)
                OR (@cityName is null and @countryName is not null)
                )
                BEGIN
                    ;
                    THROW 52000,
                        'Nalezy podac nazwe miasta i nazwe kraju albo zadne ', 1;
                END
            IF (@cityName is not null and @countryName is not null)
                BEGIN
                    DECLARE @countryID int
                    EXEC sp_FindCountry
                         @countryName,
                         @countryID = @countryID out
                    SET @cityID = (Select cityID
                                   From Cities
                                   Where CountryID = @countryID
                                     and CityName = @cityName)
                    IF (@cityID is null)
                        BEGIN
                            INSERT INTO Cities(CityName, CountryID)
                            VALUES (@cityName, @countryID);
                            SET @cityID = @@IDENTITY;
                        END
                END
        COMMIT TRAN FIND_CITY_BY_NAME
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN FIND_CITY_BY_NAME
        DECLARE @msg NVARCHAR(2048) =
            'Bład wyszukiwania miasta:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_FindCountry] @countryName varchar(255),
                                        @countryID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN FIND_COUNTRY
            SET @countryID = (Select CountryID
                              From Countries
                              Where CountryName = @countryName)
            IF (@countryID is null)
                BEGIN
                    INSERT INTO Countries(CountryName)
                    VALUES (@countryName);
                    SET @countryID = @@IDENTITY;
                END
        COMMIT TRAN FIND_COUNTRY
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN FIND_COUNTRY
        DECLARE @msg NVARCHAR(2048) =
            'Bład wyszukiwania kraju:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_InsertClient] @email varchar(255),
                                         @address varchar(255) = NULL,
                                         @cityName varchar(255) = NULL,
                                         @countryName varchar(255) = NULL,
                                         @postalCode varchar(255) = NULL,
                                         @clientID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @cityID int
        EXEC sp_FindCity
             @cityName,
             @countryName,
             @cityID = @cityID OUTPUT
        INSERT INTO Clients(Email, Address, PostalCode, CityID)
        VALUES (@email,
                @address,
                @postalCode,
                @cityID);
        SET @clientID = @@IDENTITY


    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(2048) =
                'Blad w dodawaniu klienta do bazy:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_InsertPerson] @firstname varchar(255) = NULL,
                                         @lastname varchar(255) = NULL,
                                         @phone varchar(255) = NULL,
                                         @personID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO Person(Firstname, Lastname, Phone)
        VALUES (@firstname,
                @lastname,
                @phone);
        SET @personID = @@IDENTITY
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(2048) =
            'Blad dodania osoby do bazy:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_PayReservation] @reservationID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN PayReservation
            IF ((SELECT PaymentDate
                 FROM Reservations
                 WHERE ReservationID = @reservationID) is not null)
                BEGIN
                    ;THROW 52000,'Rezerwacja jest oplacona',1;
                END
            UPDATE Reservations
            SET PaymentDate = GETDATE()
            WHERE ReservationID = @reservationID
        COMMIT TRAN PayReservation
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN PayReservation
        DECLARE @msg NVARCHAR(2048) = 'Bład zaplacenia rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
end
go

CREATE PROCEDURE [dbo].[sp_RemoveAttendee] @attendeeID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN RemoveAttendee
            IF ((Select Count(AttendeeID)
                 From Attendees
                 WHERE AttendeeID = @attendeeID) < 1)
                BEGIN
                    ;
                    THROW 52000,
                        'Nie znaleziono uczestika o podanym ID',
                        1;
                END
            DELETE
            from Attendees
            WHERE AttendeeID = @attendeeID
        COMMIT TRAN RemoveAttendee
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN RemoveAttendee
        DECLARE @msg NVARCHAR(2048) =
                'Bład usuniecia participanta:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_RemoveOldReservations]
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN RemoveOldReservations
            DELETE
            FROM Reservations
            WHERE PaymentDate is null
              and DATEDIFF(d, ReservationDate, GETDATE()) >= 7
        COMMIT TRAN RemoveOldReservations
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN RemoveOldReservations
        DECLARE @msg NVARCHAR(2048) = 'Bład usuniecia rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_RemoveReservation] @reservationID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN RemoveReservation
            IF ((SELECT PaymentDate
                 FROM Reservations
                 WHERE ReservationID = @reservationID) is not null)
                BEGIN
                    ;THROW 52000,'Rezerwacja jest oplacona',1;
                END
            IF ((SELECT COUNT(ReservationID)
                 FROM Reservations
                 WHERE ReservationID = @reservationID) < 1)
                BEGIN
                    ;THROW 52000,'Nie znaleziono rezerwacji',1;
                END
            DELETE
            FROM Reservations
            WHERE ReservationID = @reservationID
        COMMIT TRAN RemoveReservation
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN RemoveReservation
        DECLARE @msg NVARCHAR(2048) =
            'Bład usuniecia rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_RemoveReservationDay] @reservationDayID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN RemoveReservationDay
            IF ((SELECT PaymentDate
                 FROM Reservations as R
                          JOIN [ReservationDays] as RD
                               ON RD.ReservationID = R.ReservationID
                 WHERE @reservationDayID = RD.ReservationDayID) is not null)
                BEGIN
                    ;
                    THROW 52000,'Rezerwacja jest oplacona',
                        1;
                END
            IF ((SELECT COUNT(RD.ReservationDayID)
                 From [ReservationDays] as RD
                 WHERE @reservationDayID = RD.ReservationDayID) < 1)
                BEGIN
                    ;
                    THROW 52000,'Nie znaleziono rezerwacji',
                        1;
                END
            DELETE
            FROM [ReservationDays]
            WHERE @reservationDayID = ReservationDayID
        COMMIT TRAN RemoveReservationDay
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN RemoveReservationDay
        DECLARE @msg NVARCHAR(2048) =
                'Bład usuniecia rezerwacji:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_RemoveReservationWorkshop] @workshopReservationID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN RemoveReservationWorkshop
            IF ((SELECT PaymentDate
                 FROM Reservations as R
                          JOIN [ReservationDays] as RD
                               ON RD.ReservationID = R.ReservationID
                          JOIN [WorkshopReservations] as WR
                               ON WR.ReservationDayID = RD.ReservationDayID
                 WHERE WR.WorkshopReservationID = @workshopReservationID) is not null)
                BEGIN
                    ;
                    THROW 52000,'Rezerwacja jest oplacona',
                        1;
                END
            IF ((SELECT COUNT(WR.WorkshopReservationID)
                 FROM [WorkshopReservations] as WR
                 WHERE WR.WorkshopReservationID = @workshopReservationID) < 1)
                BEGIN
                    ;
                    THROW 52000,'Nie znaleziono rezerwacji',
                        1;
                END
            DELETE
            FROM [WorkshopAttendees]
            WHERE WorkshopReservationID = @workshopReservationID
            DELETE
            FROM [WorkshopReservations]
            WHERE WorkshopReservationID = @workshopReservationID
        COMMIT TRAN RemoveReservationWorkshop
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN RemoveReservationWorkshop
        DECLARE @msg NVARCHAR(2048) =
                'Bład usuniecia rezerwacji:' +
                CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
end
go

CREATE PROCEDURE [dbo].[sp_RemoveWorkshopAttendee] @attendeeID int,
                                                   @WorkshopReservationID int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN RemoveWorkshopAttendee
            IF ((SELECT COUNT(AttendeeID)
                 FROM [WorkshopAttendees]
                 WHERE AttendeeID = @attendeeID
                   and @WorkshopReservationID = WorkshopReservationID) < 1)
                BEGIN
                    ;THROW 52000,'Nie znaleziono polaczenia miedzy warsztatem a uczestnikiem', 1;
                END
            DELETE
            from [WorkshopAttendees]
            WHERE AttendeeID = @attendeeID
              and @WorkshopReservationID = WorkshopReservationID
        COMMIT TRAN RemoveWorkshopAttendee
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN RemoveWorkshopAttendee
        DECLARE @msg NVARCHAR(2048) = 'Bład usuniecia rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_UpdateConference] @conferenceID int,
                                             @ConferenceName varchar(255) = null, @studentDiscount float = null,
                                             @Address varchar(255) = null, @postalCode varchar(255) = null,
                                             @limit int = null, @price money = null, @city varchar(255) = null,
                                             @country varchar(255) = null
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN UpdateConference
            if @limit is not null
                begin
                    IF ((Select COUNT(ConferenceDayID)
                         FROM [ConferencesDays]
                         WHERE conferenceID = @conferenceID
                           and dbo.sf_GetConferenceDayUsedPlaces(ConferenceDayID) > @limit) > 0)
                        BEGIN
                            ;THROW 52000,'Nie mozna zmniejszc ilosci miejsc poniżej liczby osob ktere juz zarezerwowaly konferencje', 1;
                        END


                    UPDATE Conferences
                    SET Limit = @limit
                    WHERE ConferenceID = @conferenceID
                end
            if @ConferenceName is not null
                begin
                    Update Conferences set ConferenceName = @ConferenceName where ConferenceID = @conferenceID
                end
            if @studentDiscount is not null
                begin
                    Update Conferences set StudentDiscount = @studentDiscount where ConferenceID = @conferenceID
                end
            if @Address is not null
                begin
                    Update Conferences set Address = @Address where ConferenceID = @conferenceID
                end
            if @postalCode is not null
                begin
                    Update Conferences set PostalCode = @postalCode where ConferenceID = @conferenceID
                end
            if @price is not null
                begin
                    Update Conferences set Price = @price where ConferenceID = @conferenceID
                end
            if @city is not null and @country is not null
                begin
                    DECLARE @cityID int
                    EXEC sp_FindCity
                         @city,
                         @country,
                         @cityID = @cityID out
                    Update Conferences set CityID = @cityID where ConferenceID = @conferenceID

                end
        COMMIT TRAN UpdateConference
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN UpdateConference
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany konferencji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_UpdatePerson] @personId int,
                                         @firstname varchar(255) = null,
                                         @lastname varchar(255) = null,
                                         @phone varchar(255) = null
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN UpdatePerson
            if @firstname is not null
                begin
                    Update Person set Firstname = @firstname where PersonID = @personId
                end
            if @lastname is not null
                begin
                    Update Person set Lastname = @lastname where PersonID = @personId
                end
            if @phone is not null
                begin
                    Update Person set Phone = @phone where PersonID = @personId
                end
        COMMIT TRAN UpdatePerson
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN UpdatePerson
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany danych osobowych:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_UpdateReservationDay] @reservationDayID int,
                                                 @normalTickets int,
                                                 @studentTickets int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN UpdateReservationDay
            IF ((select count(*)
                 from ReservationDays
                          join Reservations R2 on ReservationDays.ReservationID = R2.ReservationID
                          join IndividualClients IC on R2.ClientID = IC.ClientID
                 where ReservationDayID = @reservationDayID
                ) > 0)
                BEGIN
                    ;THROW 52000,'Nie mozna zmienic ilsoci miejsc dla osoby prywatnej', 1;
                END

            IF (@normalTickets + @studentTickets = 0)
                BEGIN
                    ;THROW 52000,'Trzeba rezerwowac przynajmniej jedno miejsce', 1;
                END

            IF ((SELECt R.PaymentDate
                 FROM REservations as R
                          JOIN [ReservationDays] as RD
                               on RD.ReservationID = R.ReservationID
                 WHERE RD.ReservationDayID = @reservationDayID) is not null)
                BEGIN
                    ;THROW 52000,'Rezerwacja już opłacona', 1;
                END

            IF (dbo.sf_GetReservationDayNormalUsed(@reservationDayID) > @normalTickets
                or dbo.sf_GetReservationDayStudentUsed(@reservationDayID) > @studentTickets)
                BEGIN
                    ;THROW 52000,'Nie można zmienić na ilośc mniejsza niz ilosc przypisanych uzytkownikow', 1;
                END
            DECLARE @conferenceDayID int = (SELECT ConferenceDayID
                                            FROM [ReservationDays] as RD
                                            WHERE RD.ReservationDayID = @reservationDayID)
            IF (dbo.sf_GetConferenceDayFreePlaces(@conferenceDayID) <
                @normalTickets + @studentTickets - dbo.sf_GetReservationDayNormalUsed(@reservationDayID) -
                dbo.sf_GetReservationDayStudentUsed(@reservationDayID))
                BEGIN
                    ;THROW 52000,'Niestety nie ma wystarczajacej ilosci wolnych miejsc', 1;
                END
            UPDATE [ReservationDays]
            SET NormalTickets  = @normalTickets,
                StudentTickets = @studentTickets
            WHERE ReservationDayID = @reservationDayID
        COMMIT TRAN UpdateReservationDay
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN UpdateReservationDay
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_UpdateReservationWorkshop] @workshopReservationID int,
                                                      @normalTickets int,
                                                      @studentTickets int
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN UpdateReservationWorkshop
            IF (@normalTickets + @studentTickets = 0)
                BEGIN
                    ;THROW 52000,'Trzeba rezerwowac przynajmniej jedno miejsce', 1;
                END
            IF ((SELECt R.PaymentDate
                 FROM REservations as R
                          JOIN [ReservationDays] as RD
                               on RD.ReservationID = R.ReservationID
                          JOIN [WorkshopReservations] as WR
                               ON WR.ReservationDayID = RD.ReservationDayID
                 WHERE WR.workshopReservationID = @workshopReservationID) is not null)
                BEGIN
                    ;THROW 52000,'Rezerwacja już opłacona', 1;
                END
            IF (dbo.sf_GetWorkshopReservationNormalUsed(@workshopReservationID) > @normalTickets
                or dbo.sf_GetWorkshopReservationStudentUsed(@workshopReservationID) > @studentTickets)
                BEGIN
                    ;THROW 52000,'Nie można zmienić n a ilośc mniejsza niz ilosc przypisanych uzytkownikow', 1;
                END
            DECLARE @workshopDetailsID int = (SELECT WorkshopDetailsID
                                              FROM [WorkshopReservations] as WR
                                              WHERE WR.WorkshopReservationID = @workshopReservationID)
            IF (dbo.sf_GetWorkshopDetailsFreePlaces(@workshopDetailsID) <
                @normalTickets + @studentTickets - dbo.sf_GetWorkshopReservationNormalUsed(@workshopReservationID) -
                dbo.sf_GetWorkshopReservationStudentUsed(@workshopReservationID))
                BEGIN
                    ;THROW 52000,'Niestety nie ma wystarczajacej ilosci wolnych miejsc', 1;
                END
            DECLARE @reservationDayID int = (SELECT WR.reservationDayID
                                             FROM [WorkshopReservations] as WR
                                             WHERE WR.workshopReservationID = @workshopReservationID)
            IF (dbo.sf_GetReservationDayNormal(@reservationDayID) < @normalTickets or
                dbo.sf_GetReservationDayStudent(@reservationDayID) < @studentTickets)
                BEGIN
                    ;THROW 52000,'Nie mozna rezerwowac wiekszej ilosci miejsc niz w rezerwacji na dzien konferencji', 1;
                END
            UPDATE [WorkshopReservations]
            SET NormalTickets  = @normalTickets,
                StudentTickets = @studentTickets
            WHERE workshopReservationID = @workshopReservationID
        COMMIT TRAN UpdateReservationWorkshop
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN UpdateReservationWorkshop
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany rezerwacji:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go

CREATE PROCEDURE [dbo].[sp_UpdateWorkshop] @WorkshopDetailsID int,
                                           @limit int = null,
                                           @price money = null
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN UpdateConference
            if @limit is not null
                begin

                    IF (dbo.sf_GetWorkshopDetailsUsedPlaces(@workshopDetailsID) > @limit)
                        BEGIN
                            ;THROW 52000,'Nie mozna zmniejszc ilosci miejsc poniżej liczby zarezerwowanych juz miejsc', 1;
                        END
                    DECLARE @conferenceID int = (SELECT conferenceID
                                                 FROM [WorkshopDetails] as WI
                                                          JOIN [ConferencesDays] as CD
                                                               on CD.ConferenceDayID = WI.ConferenceDayID
                                                 WHERE WI.WorkshopDetailsID = @WorkshopDetailsID)
                    IF (dbo.sf_GetConferenceLimit(@conferenceID) < @limit)
                        BEGIN
                            ;THROW 52000,'Limit miejsc nie mo że być wieksza od liczby miejsc na konferencje', 1;
                        END

                    UPDATE [WorkshopDetails]
                    SET Limit = @limit
                    WHERE WorkshopDetailsID = @WorkshopDetailsID
                end
            if @price is not null
                begin
                    update WorkshopDetails set Price = @price where WorkshopDetailsID = @WorkshopDetailsID
                end
        COMMIT TRAN UpdateConference
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN UpdateConference
        DECLARE @msg NVARCHAR(2048) = 'Bład zmiany warsztatu:' + CHAR(13) + CHAR(10) + ERROR_MESSAGE();
        THROW 52000,@msg, 1;
    END CATCH
END
go






