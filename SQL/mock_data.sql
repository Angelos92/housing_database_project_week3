-- Mock data for the rental listings schema
-- Run this AFTER schema.sql has created the tables

-- ---------------------------------------------------
-- Lookup tables (no foreign keys)
-- ---------------------------------------------------

INSERT INTO LandlordType (TypeName) VALUES
('Private Individual'),
('Real Estate Agency'),
('Housing Corporation'),
('Property Management Company');

INSERT INTO RentalStatus (StatusName) VALUES
('Available'),
('Under Offer'),
('Rented'),
('Withdrawn');

INSERT INTO HousingType (TypeName) VALUES
('Apartment'),
('Studio'),
('Townhouse'),
('Detached House'),
('Room in Shared House');

INSERT INTO Location (Neighborhood, Street, PostalCode, City) VALUES
('Kralingen', 'Oostzeedijk 12', '3063BA', 'Rotterdam'),
('Noord', 'Bergselaan 45', '3038AR', 'Rotterdam'),
('Centrum', 'Coolsingel 88', '3012AG', 'Rotterdam'),
('Delfshaven', 'Schiedamseweg 210', '3025AG', 'Rotterdam'),
('Feijenoord', 'Beijerlandselaan 34', '3072EJ', 'Rotterdam'),
('Jordaan', 'Elandsgracht 15', '1016TN', 'Amsterdam'),
('De Pijp', 'Ferdinand Bolstraat 60', '1072LM', 'Amsterdam'),
('Oud-West', 'Kinkerstraat 100', '1053ED', 'Amsterdam'),
('Binnenstad', 'Neude 5', '3512AC', 'Utrecht'),
('Wittevrouwen', 'Biltstraat 120', '3572AT', 'Utrecht');

-- ---------------------------------------------------
-- Tables with foreign keys
-- ---------------------------------------------------

INSERT INTO Landlord (LandlordTypeId, LandlordName) VALUES
(1, 'Jan de Vries'),
(2, 'Rotterdam Rentals BV'),
(3, 'Woonstad Rotterdam'),
(1, 'Els Bakker'),
(4, 'Prime Property Management'),
(2, 'Amsterdam Housing Agents'),
(1, 'Peter Jansen'),
(3, 'Mitros Woningcorporatie');

INSERT INTO Property (LocationId, HousingTypeId, SizeM2) VALUES
(1, 1, 65),
(2, 2, 30),
(3, 1, 85),
(4, 3, 110),
(5, 5, 18),
(6, 1, 55),
(7, 4, 140),
(8, 2, 28),
(9, 1, 72),
(10, 3, 95);

INSERT INTO Listing (RentalStatusId, PropertyId, LandlordId, Price, Website) VALUES
(1, 1, 1, 1250.00, 'https://example-listings.com/listing/1001'),
(1, 2, 2, 850.00, 'https://example-listings.com/listing/1002'),
(3, 3, 3, 1450.00, 'https://example-listings.com/listing/1003'),
(2, 4, 4, 1975.00, 'https://example-listings.com/listing/1004'),
(1, 5, 5, 650.00, NULL),
(4, 6, 6, 1100.00, 'https://example-listings.com/listing/1006'),
(1, 7, 7, 3200.00, 'https://example-listings.com/listing/1007'),
(1, 8, 8, 900.00, NULL),
(3, 9, 1, 1350.00, 'https://example-listings.com/listing/1009'),
(2, 10, 2, 1800.00, 'https://example-listings.com/listing/1010');
