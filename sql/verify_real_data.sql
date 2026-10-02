-- Select your imported database first: USE housing_utrecht;
SELECT d.DatasetId, d.TotalRows, d.SelectedRows, d.ExcludedRows,
       COUNT(r.SourceRow) AS StoredSourceRecords,
       SUM(r.RecordStatus='accepted') AS Accepted,
       SUM(r.RecordStatus='rejected') AS Rejected
FROM SourceDataset d
JOIN SourceRecord r ON r.DatasetId=d.DatasetId
GROUP BY d.DatasetId,d.TotalRows,d.SelectedRows,d.ExcludedRows;

SELECT 'Property' AS TableName,COUNT(*) AS ImportedRows FROM Property
UNION ALL SELECT 'Location',COUNT(*) FROM Location
UNION ALL SELECT 'Region',COUNT(*) FROM Region
UNION ALL SELECT 'RegionStatistics',COUNT(*) FROM RegionStatistics
UNION ALL SELECT 'PropertyMeasurement',COUNT(*) FROM PropertyMeasurement
UNION ALL SELECT 'PropertySourceAttribute',COUNT(*) FROM PropertySourceAttribute
UNION ALL SELECT 'Listing',COUNT(*) FROM Listing
UNION ALL SELECT 'Landlord',COUNT(*) FROM Landlord;

-- Must return zero: accepted source records without their operational entity.
SELECT COUNT(*) AS AcceptedRecordsWithoutEntity
FROM SourceRecord r
WHERE r.RecordStatus='accepted' AND (
 (r.DatasetId='utrecht' AND NOT EXISTS (
   SELECT 1 FROM Property p WHERE p.DatasetId=r.DatasetId AND p.SourceRow=r.SourceRow))
 OR (r.DatasetId='cbs2025' AND NOT EXISTS (
   SELECT 1 FROM RegionStatistics s WHERE s.DatasetId=r.DatasetId AND s.SourceRow=r.SourceRow))
);

SELECT RegionLevel, COUNT(*) AS RegionCount FROM Region GROUP BY RegionLevel;

-- No neighbourhood match has been verified for these individual houses.
SELECT COUNT(*) AS PropertiesWithoutVerifiedNeighborhood
FROM Property p JOIN Location l ON l.LocationId=p.LocationId
WHERE l.NeighborhoodCode IS NULL;

-- Example CBS-only query: neighbourhood statistics, without double-counting totals.
SELECT r.RegionCode,r.RegionName,s.DwellingCount,s.RentalSharePct,s.AverageWozThousandsEUR
FROM Region r JOIN RegionStatistics s
 ON s.BoundaryYear=r.BoundaryYear AND s.RegionCode=r.RegionCode
WHERE r.RegionLevel='Buurt' AND s.StatisticsYear=2025
ORDER BY r.RegionCode LIMIT 10;
