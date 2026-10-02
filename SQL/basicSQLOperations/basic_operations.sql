-- Add new housing type.
INSERT INTO HousingType (TypeName)
VALUES 
('Room'),
('Studio'),
('House'),
('Apartment');

-- Delete a housing type.
DELETE FROM HousingType
WHERE HousingTypeId = 3;

-- Update a housing type.
UPDATE HousingType
SET TypeName = 'Condo'
WHERE HousingTypeId = 4;

-- Add Location
INSERT INTO Location (Neighborhood, Street, PostalCode, City)
VALUES 
('n/a','Loremstraat', 1234, 'Amsterdam');

-- Delete a Location
DELETE FROM Location
WHERE LocationId = 1;

-- Update a Location
UPDATE Location
SET Neighborhood = 'Centrum'
WHERE LocationId = 1;

-- Add Property
INSERT INTO Property (LocationId, HousingtypeId, SizeM2)
VALUES 
(1, 3, 60);

-- Update Property
UPDATE Property
SET HousingTypeId = 2
WHERE HousingTypeId = 3;

-- Delete a name of a rental Status.
DELETE FROM RentalStatus
WHERE StatusName = 'Sale';

-- Add a name of a rental Status.]
INSERT INTO RentalStatus (StatusName)
VALUES 
('Rental'),
('Sale');

-- Update a name of a rental Status.
UPDATE RentalStatus
SET StatusName = 'Rented'
WHERE StatusName = 'Rental';