DROP TABLE IF EXISTS Listing;
DROP TABLE IF EXISTS Property;
DROP TABLE IF EXISTS Landlord;
DROP TABLE IF EXISTS Location;
DROP TABLE IF EXISTS HousingType;
DROP TABLE IF EXISTS RentalStatus;
DROP TABLE IF EXISTS LandlordType;

-- Tables with no foreign keys

CREATE TABLE Location (
    LocationId   INT PRIMARY KEY AUTO_INCREMENT,
    Neighborhood VARCHAR(100) NOT NULL,
    Street       VARCHAR(100) NOT NULL,
    PostalCode   VARCHAR(10) NOT NULL,
    City         VARCHAR(100) NOT NULL
);

CREATE TABLE HousingType (
    HousingTypeId INT PRIMARY KEY AUTO_INCREMENT,
    TypeName      VARCHAR(50) NOT NULL
);

CREATE TABLE RentalStatus (
    RentalStatusId INT PRIMARY KEY AUTO_INCREMENT,
    StatusName     VARCHAR(50) NOT NULL
);

CREATE TABLE LandlordType (
    LandlordTypeId INT PRIMARY KEY AUTO_INCREMENT,
    TypeName       VARCHAR(50) NOT NULL
);

-- Tables with foreign keys

CREATE TABLE Landlord (
    LandlordId     INT PRIMARY KEY AUTO_INCREMENT,
    LandlordTypeId INT NOT NULL,
    LandlordName   VARCHAR(100) NOT NULL,
    FOREIGN KEY (LandlordTypeId) REFERENCES LandlordType(LandlordTypeId)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE Property (
    PropertyId    INT PRIMARY KEY AUTO_INCREMENT,
    LocationId    INT NOT NULL,
    HousingTypeId INT NOT NULL,
    SizeM2        INT NOT NULL CHECK (SizeM2 > 0),
    FOREIGN KEY (LocationId) REFERENCES Location(LocationId)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (HousingTypeId) REFERENCES HousingType(HousingTypeId)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE Listing (
    ListingId      INT PRIMARY KEY AUTO_INCREMENT,
    RentalStatusId INT NOT NULL,
    PropertyId     INT NOT NULL,
    LandlordId     INT NOT NULL,
    Price          DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
    Website        VARCHAR(2048),
    FOREIGN KEY (RentalStatusId) REFERENCES RentalStatus(RentalStatusId)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (PropertyId) REFERENCES Property(PropertyId)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (LandlordId) REFERENCES Landlord(LandlordId)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);