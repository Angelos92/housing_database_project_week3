-- MySQL 8.0.16+ (enforced CHECK constraints). Run only in a fresh database.
-- Revised Week 3 model. No DROP statements, mock records or invented listings.
CREATE TABLE SourceDataset (
 DatasetId VARCHAR(20) PRIMARY KEY,
 FileName VARCHAR(255) NOT NULL,
 Sha256 CHAR(64) NOT NULL,
 TotalRows INT NOT NULL,
 SelectedRows INT NOT NULL,
 ExcludedRows INT NOT NULL,
 CHECK (TotalRows = SelectedRows + ExcludedRows)
) ENGINE=InnoDB;

CREATE TABLE SourceRecord (
 DatasetId VARCHAR(20) NOT NULL,
 SourceRow INT NOT NULL,
 SourceIdentifier VARCHAR(50),
 RawValues JSON NOT NULL,
 RecordStatus VARCHAR(10) NOT NULL CHECK (RecordStatus IN ('accepted','rejected')),
 RejectionReason TEXT,
 PRIMARY KEY (DatasetId, SourceRow),
 FOREIGN KEY (DatasetId) REFERENCES SourceDataset(DatasetId)
) ENGINE=InnoDB;

CREATE TABLE Region (
 BoundaryYear SMALLINT NOT NULL,
 RegionCode VARCHAR(10) NOT NULL,
 RegionName VARCHAR(255) NOT NULL,
 RegionLevel VARCHAR(10) NOT NULL CHECK (RegionLevel IN ('Gemeente','Wijk','Buurt')),
 ParentCode VARCHAR(10),
 PRIMARY KEY (BoundaryYear, RegionCode),
 FOREIGN KEY (BoundaryYear, ParentCode) REFERENCES Region(BoundaryYear, RegionCode)
) ENGINE=InnoDB;

CREATE TABLE RegionStatistics (
 BoundaryYear SMALLINT NOT NULL,
 RegionCode VARCHAR(10) NOT NULL,
 StatisticsYear SMALLINT NOT NULL,
 DatasetId VARCHAR(20) NOT NULL,
 SourceRow INT NOT NULL,
 Population INT CHECK (Population >= 0),
 Households INT CHECK (Households >= 0),
 DwellingCount INT CHECK (DwellingCount >= 0),
 AverageWozThousandsEUR DECIMAL(14,3) CHECK (AverageWozThousandsEUR >= 0),
 RentalSharePct DECIMAL(6,3) CHECK (RentalSharePct BETWEEN 0 AND 100),
 CorporationSharePct DECIMAL(6,3) CHECK (CorporationSharePct BETWEEN 0 AND 100),
 OtherLandlordSharePct DECIMAL(6,3) CHECK (OtherLandlordSharePct BETWEEN 0 AND 100),
 DominantPostalCode CHAR(4),
 PRIMARY KEY (BoundaryYear, RegionCode, StatisticsYear),
 UNIQUE (DatasetId, SourceRow),
 FOREIGN KEY (BoundaryYear, RegionCode) REFERENCES Region(BoundaryYear, RegionCode),
 FOREIGN KEY (DatasetId, SourceRow) REFERENCES SourceRecord(DatasetId, SourceRow)
) ENGINE=InnoDB;

CREATE TABLE Location (
 LocationId INT PRIMARY KEY,
 Street VARCHAR(255),
 PostalCodePrefix CHAR(4),
 City VARCHAR(100),
 XCoordinate DECIMAL(16,4),
 YCoordinate DECIMAL(16,4),
 CoordinateSystem VARCHAR(100),
 NeighborhoodBoundaryYear SMALLINT,
 NeighborhoodCode VARCHAR(10),
 FOREIGN KEY (NeighborhoodBoundaryYear, NeighborhoodCode)
   REFERENCES Region(BoundaryYear, RegionCode),
 CHECK ((NeighborhoodBoundaryYear IS NULL AND NeighborhoodCode IS NULL)
     OR (NeighborhoodBoundaryYear IS NOT NULL AND NeighborhoodCode IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE HousingType (
 HousingTypeId INT PRIMARY KEY AUTO_INCREMENT,
 TypeName VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE Property (
 PropertyId INT PRIMARY KEY,
 DatasetId VARCHAR(20) NOT NULL,
 SourceRow INT NOT NULL,
 ExternalId VARCHAR(50) NOT NULL,
 LocationId INT NOT NULL,
 HousingTypeId INT,
 BuildYear SMALLINT CHECK (BuildYear BETWEEN 1000 AND 9999),
 Bathrooms SMALLINT CHECK (Bathrooms >= 0),
 UNIQUE (DatasetId, ExternalId),
 UNIQUE (DatasetId, SourceRow),
 FOREIGN KEY (DatasetId, SourceRow) REFERENCES SourceRecord(DatasetId, SourceRow),
 FOREIGN KEY (LocationId) REFERENCES Location(LocationId),
 FOREIGN KEY (HousingTypeId) REFERENCES HousingType(HousingTypeId)
) ENGINE=InnoDB;

CREATE TABLE MeasurementDefinition (
 MeasureCode VARCHAR(30) PRIMARY KEY,
 Description VARCHAR(255) NOT NULL,
 UnitName VARCHAR(50)
) ENGINE=InnoDB;

CREATE TABLE PropertyMeasurement (
 PropertyId INT NOT NULL,
 MeasureCode VARCHAR(30) NOT NULL,
 NumericValue DECIMAL(18,4) NOT NULL CHECK (NumericValue >= 0),
 PRIMARY KEY (PropertyId, MeasureCode),
 FOREIGN KEY (PropertyId) REFERENCES Property(PropertyId),
 FOREIGN KEY (MeasureCode) REFERENCES MeasurementDefinition(MeasureCode)
) ENGINE=InnoDB;

CREATE TABLE SourceAttributeDefinition (
 AttributeCode VARCHAR(30) PRIMARY KEY,
 Description VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE PropertySourceAttribute (
 PropertyId INT NOT NULL,
 AttributeCode VARCHAR(30) NOT NULL,
 SourceCode INT NOT NULL,
 PRIMARY KEY (PropertyId, AttributeCode),
 FOREIGN KEY (PropertyId) REFERENCES Property(PropertyId),
 FOREIGN KEY (AttributeCode) REFERENCES SourceAttributeDefinition(AttributeCode)
) ENGINE=InnoDB;

CREATE TABLE RentalStatus (
 RentalStatusId INT PRIMARY KEY AUTO_INCREMENT, StatusName VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE LandlordType (
 LandlordTypeId INT PRIMARY KEY AUTO_INCREMENT, TypeName VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE Landlord (
 LandlordId INT PRIMARY KEY AUTO_INCREMENT,
 LandlordTypeId INT NOT NULL,
 LandlordName VARCHAR(100) NOT NULL,
 FOREIGN KEY (LandlordTypeId) REFERENCES LandlordType(LandlordTypeId)
) ENGINE=InnoDB;

CREATE TABLE Listing (
 ListingId INT PRIMARY KEY AUTO_INCREMENT,
 RentalStatusId INT NOT NULL,
 PropertyId INT NOT NULL,
 LandlordId INT NOT NULL,
 Price DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
 Website VARCHAR(2048),
 FOREIGN KEY (RentalStatusId) REFERENCES RentalStatus(RentalStatusId),
 FOREIGN KEY (PropertyId) REFERENCES Property(PropertyId),
 FOREIGN KEY (LandlordId) REFERENCES Landlord(LandlordId)
) ENGINE=InnoDB;
