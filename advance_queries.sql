-- 1. Average rental price per city, only for cities with more 
-- than one listing (multi-table JOIN + GROUP BY + HAVING)
SELECT loc.City, COUNT(*) AS NumberOfListings, ROUND(AVG(li.Price), 2) AS AveragePrice
FROM Listing li
JOIN Property p ON li.PropertyId = p.PropertyId
JOIN Location loc ON p.LocationId = loc.LocationId
GROUP BY loc.City
HAVING COUNT(*) > 1
ORDER BY AveragePrice DESC;


--2. Housing types that currently have no listing at all (anti-join pattern using NOT EXISTS)
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