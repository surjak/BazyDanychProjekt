create table Countries
(
    CountryID   int identity
        constraint Countries_pk
            primary key,
    CountryName varchar(255) not null
        constraint UQ_Countries_CountryName
            unique
)
go

create table Cities
(
    CityID    int identity
        constraint Cities_pk
            primary key,
    CityName  varchar(255) not null,
    CountryID int          not null
        constraint Cities_Countries_CountryID_fk
            references Countries
)
go

create unique index Cities_CityID_uindex
    on Cities (CityID)
go

create table Clients
(
    ClientID   int identity
        constraint Clients_pk
            primary key,
    Email      varchar(255) not null
        constraint Clients_Email_UQ
            unique
        constraint Clients_Email_CK
            check ([Email] like '%@%'),
    Address    varchar(255),
    PostalCode varchar(255)
        constraint Clients_PostalCode_CK
            check ([PostalCode] like '[0-9][0-9]-[0-9][0-9][0-9]' OR [PostalCode] like '[0-9][0-9][0-9][0-9][0-9]'),
    CityID     int          not null
        constraint Clients_Cities_CityID_fk
            references Cities
)
go

create unique index Clients_ClientID_uindex
    on Clients (ClientID)
go

create table Companies
(
    ClientID    int          not null
        constraint Companies_pk
            primary key
        constraint Companies_Clients_ClientID_fk
            references Clients,
    CompanyName varchar(255) not null,
    NIP         char(10)     not null
        constraint UQ_Companies_NIP
            unique,
    ContactName varchar(255) not null,
    Phone       varchar(255) not null
        constraint CK_Companies_Phone
            check (isnumeric([Phone]) = 1)
)
go

create unique index Companies_ClientID_uindex
    on Companies (ClientID)
go

create unique index Companies_NIP_uindex
    on Companies (NIP)
go

create unique index Countries_CountryID_uindex
    on Countries (CountryID)
go

create table Organizers
(
    OrganizerID int identity
        constraint Organizers_pk
            primary key,
    CompanyName varchar(255) not null,
    NIP         char(10)     not null
        constraint UQ_Organizers_NIP
            unique,
    ContactName varchar(255) not null,
    Email       varchar(255) not null
        constraint UQ_Organizers_Email
            unique
        constraint CK_Organizers_Email
            check ([Email] like '%@%'),
    Phone       varchar(255) not null
        constraint CK_Organizers_Phone
            check (isnumeric([Phone]) = 1),
    Address     varchar(255),
    PostalCode  varchar(255)
        constraint CK_Organizers_PostalCode
            check ([PostalCode] like '[0-9][0-9]-[0-9][0-9][0-9]' OR [PostalCode] like '[0-9][0-9][0-9][0-9][0-9]'),
    CityID      int          not null
        constraint Organizers_Cities_CityID_fk
            references Cities
)
go

create table Conferences
(
    ConferenceID    int identity
        constraint Conferences_pk
            primary key,
    OrganizerID     int                              not null
        constraint Conferences_Organizers_OrganizerID_fk
            references Organizers,
    ConferenceName  varchar(255)                     not null,
    StudentDiscount float                            not null
        constraint CK_Conferences_StuDis
            check ([StudentDiscount] >= 0 AND [StudentDiscount] <= 1),
    Address         varchar(255)                     not null,
    PostalCode      varchar(255)                     not null
        constraint CK_Conferences_PostalCode
            check ([PostalCode] like '[0-9][0-9]-[0-9][0-9][0-9]' OR [PostalCode] like '[0-9][0-9][0-9][0-9][0-9]'),
    StartDate       date                             not null,
    EndDate         date                             not null,
    Limit           int                              not null
        constraint CK_Conferences_Limit
            check ([Limit] > 0),
    Canceled        bit
        constraint DF_Conferences_Canceled default 0 not null,
    Price           money
        constraint DF_Conferences_Price default 0    not null,
    CityID          int                              not null
        constraint Conferences_Cities_CityID_fk
            references Cities,
    constraint CK_Conferences_Dates
        check ([StartDate] <= [EndDate])
)
go

create unique index Conferences_ConferenceID_uindex
    on Conferences (ConferenceID)
go

CREATE TRIGGER Add_Conference_Days
    ON Conferences
    AFTER INSERT
    AS
BEGIN
    DECLARE @ConID AS int
    declare @startDate DATE
    declare @endDate DATE


    Select @ConID = ConferenceID, @startDate = StartDate, @endDate = EndDate From inserted


    DECLARE @i date = @startDate
    WHILE @i <= @endDate
        BEGIN
            INSERT INTO [ConferencesDays](ConferenceID, Date)
            VALUES (@ConID, @i)
            SET @i = DATEADD(d, 1, @i)

        END


END
go

create table ConferencesDays
(
    ConferenceDayID int identity
        constraint ConferencesDays_pk
            primary key,
    ConferenceID    int                                  not null
        constraint ConferencesDays_Conferences_ConferenceID_fk
            references Conferences,
    Date            date                                 not null,
    Canceled        bit
        constraint DF_ConferencesDays_Canceled default 0 not null
)
go

create unique index Organizers_OrganizerID_uindex
    on Organizers (OrganizerID)
go

create table Person
(
    PersonID  int identity
        constraint Person_pk
            primary key,
    Firstname varchar(255),
    Lastname  varchar(255),
    Phone     varchar(255)
        constraint CK_Person_Phone
            check (isnumeric([Phone]) = 1 OR [Phone] IS NULL)
)
go

create table Employees
(
    PersonID  int not null
        constraint Employees_pk
            primary key
        constraint Employees_Person_PersonID_fk
            references Person,
    CompanyID int not null
        constraint Employees_Companies_ClientID_fk
            references Companies
)
go

create table IndividualClients
(
    ClientID int not null
        constraint IndividualClients_pk
            primary key
        constraint IndividualClients_Clients_ClientID_fk
            references Clients,
    PersonID int not null
        constraint UQ_IndividualClients_PersonID
            unique
        constraint IndividualClients_Person_PersonID_fk
            references Person
)
go

create unique index IndividualClients_ClientID_uindex
    on IndividualClients (ClientID)
go

create unique index Person_PersonID_uindex
    on Person (PersonID)
go

create table Prices
(
    PriceID       int identity
        constraint Prices_pk
            primary key,
    ConferenceID  int   not null
        constraint Prices_Conferences_ConferenceID_fk
            references Conferences,
    StartDate     date  not null,
    EndDate       date  not null,
    PriceDiscount float not null
        constraint CK_Prices_Dis
            check ([PriceDiscount] >= 0 AND [PriceDiscount] <= 1),
    constraint CK_Prices_Dates
        check ([StartDate] <= [EndDate])
)
go

create unique index Prices_PriceID_uindex
    on Prices (PriceID)
go

create table Reservations
(
    ReservationID   int identity
        constraint Reservations_pk
            primary key,
    ConferenceID    int                    not null
        constraint Reservations_Conferences_ConferenceID_fk
            references Conferences,
    ClientID        int                    not null
        constraint Reservations_Clients_ClientID_fk
            references Clients,
    ReservationDate date default getdate() not null,
    PaymentDate     date,
    constraint CK_Reservations_Dates
        check (datediff(day, [PaymentDate], [ReservationDate]) <= 0)
)
go

create table ReservationDays
(
    ReservationDayID int identity
        constraint ReservationDays_pk
            primary key,
    ReservationID    int not null
        constraint ReservationDays_Reservations_ReservationID_fk
            references Reservations
            on delete cascade,
    ConferenceDayID  int not null
        constraint ReservationDays_ConferencesDays_ConferenceDayID_fk
            references ConferencesDays,
    NormalTickets    int not null
        constraint CK_ReservationDays_NormalTickets
            check ([NormalTickets] >= 0),
    StudentTickets   int not null
        constraint CK_ReservationDays_StudentTickets
            check ([StudentTickets] >= 0)
)
go

create table Attendees
(
    AttendeeID       int identity
        constraint Attendees_pk
            primary key,
    PersonID         int not null
        constraint Attendees_Person_PersonID_fk
            references Person,
    ReservationDayID int not null
        constraint Attendees_ReservationDays_ReservationDayID_fk
            references ReservationDays
            on delete cascade
)
go

create unique index ReservationDays_ReservationDayID_uindex
    on ReservationDays (ReservationDayID)
go

create unique index Reservations_ReservationID_uindex
    on Reservations (ReservationID)
go

create table Students
(
    AttendeeID    int      not null
        constraint Student_ParticipantID_UQ
            unique
        constraint Students_Attendees_AttendeeID_fk
            references Attendees
            on delete cascade,
    StudentCardID char(10) not null
)
go

create unique index Students_AttendeeID_uindex
    on Students (AttendeeID)
go

create table Workshops
(
    WorkshopID   int identity
        constraint Workshops_pk
            primary key,
    WorkshopName varchar(255) not null,
    Description  varchar(255) not null,
    OrganizerID  int          not null
        constraint Workshops_Organizers_OrganizerID_fk
            references Organizers
)
go

create table WorkshopDetails
(
    WorkshopDetailsID int identity
        constraint WorkshopDetails_pk
            primary key,
    WorkshopID        int   not null
        constraint WorkshopDetails_Workshops_WorkshopID_fk
            references Workshops,
    ConferenceDayID   int   not null
        constraint WorkshopDetails_ConferencesDays_ConferenceDayID_fk
            references ConferencesDays,
    StartTime         time  not null,
    EndTime           time  not null,
    Limit             int   not null
        constraint CK_WorkshopDetails_Limit
            check ([Limit] > 0),
    Price             money not null
        constraint CK_WorkshopDetails_Price
            check ([Price] >= 0),
    Canceled          bit   not null,
    constraint CK_WorkshopDetails_Dates
        check ([StartTime] < [EndTime])
)
go

create unique index WorkshopDetails_WorkshopDetailID_uindex
    on WorkshopDetails (WorkshopDetailsID)
go

create table WorkshopReservations
(
    WorkshopReservationID int identity
        constraint WorkshopReservations_pk
            primary key,
    WorkshopDetailsID     int not null
        constraint WorkshopReservations_WorkshopDetails_WorkshopDetailsID_fk
            references WorkshopDetails,
    NormalTickets         int
        constraint CK_WorkshopReservations_Normal
            check ([NormalTickets] >= 0),
    StudentTickets        int
        constraint CK_WorkshopReservations_Student
            check ([StudentTickets] >= 0),
    ReservationDayID      int not null
        constraint WorkshopReservations_ReservationDays_ReservationDayID_fk
            references ReservationDays
            on delete cascade
)
go

create table WorkshopAttendees
(
    WorkshopReservationID int not null
        constraint WorkshopAttendees_WorkshopReservations_WorkshopReservationID_fk
            references WorkshopReservations,
    AttendeeID            int not null
        constraint WorkshopAttendees_Attendees_AttendeeID_fk
            references Attendees
            on delete cascade,
    constraint WorkshopAttendees_pk
        primary key (WorkshopReservationID, AttendeeID)
)
go

create unique index WorkshopReservations_WorkshopReservationID_uindex
    on WorkshopReservations (WorkshopReservationID)
go

create unique index Workshops_WorkshopID_uindex
    on Workshops (WorkshopID)
go



