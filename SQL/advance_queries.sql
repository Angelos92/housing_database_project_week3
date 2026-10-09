-- 1. Average rental price per city, only for cities with more 
-- than one listing (multi-table JOIN + GROUP BY + HAVING)
SELECT loc.City, COUNT(*) AS NumberOfListings, ROUND(AVG(li.Price), 2) AS AveragePrice
FROM Listing li
JOIN Property p ON li.PropertyId = p.PropertyId
JOIN Location loc ON p.LocationId = loc.LocationId
GROUP BY loc.City
HAVING COUNT(*) > 1
ORDER BY AveragePrice DESC;


-- 2. Housing types that currently have no listing at all (anti-join pattern using NOT EXISTS)
SELECT ht.TypeName 
FROM HousingType ht
WHERE NOT EXISTS (
    SELECT 1
    FROM Property p
    JOIN Listing li ON p.PropertyId = li.PropertyId
    WHERE p.HousingTypeId = ht.HousingTypeId
);

-- 3. Listing priced BELOW the average price for 
-- their own housing type, with that average shown alongside 
-- for comparison ( derived table / JOIN + correlated subquery)
SELECT ht.TypeName AS HousingType, loc.City, li.Price, avg_price.AvgPriceForType, ROUND(avg_price.AvgPriceForType - li.Price, 2) AS BelowAverageBy
FROM Listing li
JOIN Property p ON li.PropertyId = p.PropertyId
JOIN HousingType ht ON p.HousingTypeId = ht.HousingTypeId
JOIN Location loc ON p.LocationId = loc.LocationId
JOIN (
    SELECT p2.HousingTypeId, ROUND(AVG(li2.Price), 2) AS AvgPriceForType
    FROM Listing li2
    JOIN Property p2 ON li2.PropertyId = p2.PropertyId
    GROUP BY p2.HousingTypeId
) AS avg_price ON avg_price.HousingTypeId = p.HousingTypeId
WHERE li.Price < avg_price.AvgPriceForType
ORDER BY BelowAverageBy DESC;

-- 4. neighbourhoods with the highest rental share percentage in 2025.
SELECT r.RegionName,
       s.DwellingCount,
       s.RentalSharePct
FROM Region r
JOIN RegionStatistics s
  ON r.RegionCode = s.RegionCode
 AND r.BoundaryYear = s.BoundaryYear
WHERE r.RegionLevel = 'Buurt'
  AND s.StatisticsYear = 2025
  AND s.RentalSharePct IS NOT NULL
ORDER BY s.RentalSharePct DESC, r.RegionCode
LIMIT 10;

-- Queries of K-Vesela
-- 5. how much of the housing is rented in the neighborhoods with the highest average home values
SELECT r.RegionName, s.DwellingCount,
       s.AverageWozThousandsEUR, s.RentalSharePct
FROM Region r
JOIN RegionStatistics s
  ON s.BoundaryYear = r.BoundaryYear AND s.RegionCode = r.RegionCode
WHERE r.RegionLevel = 'Buurt' AND s.StatisticsYear = 2025
  AND s.DwellingCount >= 500
  AND s.AverageWozThousandsEUR IS NOT NULL
ORDER BY s.AverageWozThousandsEUR DESC
LIMIT 10;

-- 6. how are energy labels distributed and how old are the homes in each label group?
SELECT COALESCE(EnergyLabel, 'Unknown') AS EnergyLabel,
       COUNT(*) AS Properties,
       ROUND(AVG(BuildYear)) AS AvgBuildYear
FROM Property
GROUP BY EnergyLabel
ORDER BY EnergyLabel;

--7. Properties ranked by price in euros per square meter of the property, for each city
SELECT City, Neighborhood, SizeM2, Price, PricePerM2, RANK() OVER (PARTITION BY City ORDER BY PricePerM2 DESC) AS RankInCity
FROM (
    SELECT loc.City, loc.Neighborhood, p.SizeM2, li.Price, ROUND(li.Price / p.SizeM2, 2) AS PricePerM2
    FROM Listing li
    JOIN Property p ON li.PropertyId=p.PropertyId 
    JOIN Location loc ON p.LocationId=loc.LocationId
) AS pr
ORDER BY City, RankInCity;

--8 the neighbourhoods of each city, ranked by average rent
SELECT loc.City, loc.Neighborhood, ROUND(SUM(li.Price)/ COUNT(li.Price), 2) AS AvgRent
FROM Listing li
JOIN Property p ON li.PropertyId= p.PropertyId
JOIN Location loc ON p.LocationId=loc.LocationId
GROUP BY loc.City, loc.Neighborhood
ORDER BY loc.City, AvgRent DESC;

--9.Landlords who own the most properties
SELECT l.LandlordName, COUNT(DISTINCT li.PropertyId) AS NumberOfProperties
FROM Landlord l
JOIN Listing li ON li.LandlordId=l.Landlord
GROUP BY l.Landlord, l.LandlordName
ORDER BY NumberOfProperties DESC;
