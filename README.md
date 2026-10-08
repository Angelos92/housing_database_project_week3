# housing_database_project_week3
The repository contains our group project for the KEN2110 Database course.

The goal is to design and implement a relational database that models the housing crisis in Amsterdam - tracking properties, their locations, housing types, landlords and rental listing status.

Repository: https://github.com/Angelos92/housing_database_project_week3

## Real-world data integration design


## How to work on the Repository
1. Clone the repository:
   ```bash
   git clone <repository-link>
   ```

## Important
- Always run "git pull" before starting work.
- Do not overwrite someone else's changes.
- Use clear commit messages.
- Let the team know what file you are working on to avoid conflicts.

## Database Overview
The schema has 7 tables:

**Tables with no foreign keys:**
- `Location` - neighborhood, street, postal code, city
- `HousingType` - type of housing (e.g., apartment, studio, room)
- `RentalStatus` - status of a listing (e.g., available, rented)
- `LandlordType` - type of landlord (e.g., agency, private landlord)

**Linked tables (with foreign keys):**
- `Landlord` - references `LandlordType`
- `Property` - references `Location` and `HousingType`; stores size in m²
- `Listing` - references `RentalStatus`, `Property`, and `Landlord`; stores price and listing website

All foreign keys use `ON UPDATE CASCADE` / `ON DELETE RESTRICT`, so a referenced row can't be deleted while related listings/properties still point to it.

## SQL Files

| File | Purpose |
| --- | --- |
| `schema.sql` | Drops and recreates all 7 tables, in dependency order, with primary keys, foreign keys, and constraints (e.g. `SizeM2 > 0`, `Price >= 0`) |
| `HousingTypeAdd.sql` / `HousingTypeUpdate.sql` / `HousingTypeDelete.sql` | Insert, update, and delete operations for `HousingType` |
| `LocationAdd.sql` / `LocationUpdate.sql` / `LocationDelete.sql` | Insert, update, and delete operations for `Location` |
| `PropertyAdd.sql` / `PropertyUpdate.sql` | Insert and update operations for `Property` |
| `RentalStatusNameAdd.sql` / `RentalStatusUpdate.sql` / `RentalStatusDelete.sql` | Insert, update, and delete operations for `RentalStatus` |
| `advance_queries.sql` | Three advanced queries (see below) |

## Advance SQL Queries
Three advance SQL queries were written to demonstrate multi-table joins, aggregation, anti-joins and derived tables. they can be found in ['advance_queries.sql'](./advance_queries.sql) and can be run directly against the populated database (after 'schema.sql' and 'mock_data.sql').

### 1. Average rental price per city
**Purpose:** Show the average listing price per city, useful for comparing rental market across cities, Cities with only one listing are excluded so a single outlier doesn't skew the average.
**Techniques:** multi-table 'JOIN'. 'GROUP BY', 'HAVING'.

### 2. Housing types with no active listing
**Purpose:** Identify housing Types (e.g "studio", "apartment", "Townhouse") that currently have no listing in the database at all - useful for spotting gaps in the catalogue or used reference data.
**Technique:** anti-join pattern using 'NOT EXISTS' with a correlated subquery.

### 3. Listing priced below average for their housing type
**Purpose:** Surface listing that are cheaper than the average for their own housing type - a simple way to highlight potential "good deals" for users browsing the platform. The average is computed once per housing type in a derived table and joined back, so it's shown directly alongside each price rather than hidden inside the filter condition.
**Technique:** derived table (subquery in 'FROM'), 'JOIN', 'GROUP BY', computed column.

### The performance of the original queries from Week 3
'''
mysql> SELECT loc.City, COUNT(*) AS NumberOfListings, ROUND(AVG(li.Price), 2) AS AveragePrice
    -> FROM Listing li
    -> JOIN Property p ON li.PropertyId = p.PropertyId
    -> JOIN Location loc ON p.LocationId = loc.LocationId
    -> GROUP BY loc.City
    -> HAVING COUNT(*) > 1
    -> ORDER BY AveragePrice DESC;
Empty set (0.00 sec)

mysql> SELECT ht.TypeName 
    -> FROM HousingType ht
    -> WHERE NOT EXISTS (
    ->     SELECT 1
    ->     FROM Property p
    ->     JOIN Listing li ON p.PropertyId = li.PropertyId
    ->     WHERE p.HousingTypeId = ht.HousingTypeId
    -> );
Empty set (0.00 sec)

mysql> SELECT ht.TypeName AS HousingType, loc.City, li.Price, avg_price.AvgPriceForType, ROUND(avg_price.AvgPriceForType - li.Price, 2) AS BelowAverageBy
    -> FROM Listing li
    -> JOIN Property p ON li.PropertyId = p.PropertyId
    -> JOIN HousingType ht ON p.HousingTypeId = ht.HousingTypeId
    -> JOIN Location loc ON p.LocationId = loc.LocationId
    -> JOIN (
    ->     SELECT p2.HousingTypeId, ROUND(AVG(li2.Price), 2) AS AvgPriceForType
    ->     FROM Listing li2
    ->     JOIN Property p2 ON li2.PropertyId = p2.PropertyId
    ->     GROUP BY p2.HousingTypeId
    -> ) AS avg_price ON avg_price.HousingTypeId = p.HousingTypeId
    -> WHERE li.Price < avg_price.AvgPriceForType
    -> ORDER BY BelowAverageBy DESC;
Empty set (0.01 sec)
'''
The queries returned ampty results because the selected datasets contains no rental listings or named landlords. No listing records were fabricated. therefore, these results reflect missing dadtaset coverage, not an absent of rental housing.

#### The perofrmance of new querie using the real data
mysql> SELECT r.RegionName,
    ->        s.DwellingCount,
    ->        s.RentalSharePct
    -> FROM Region r
    -> JOIN RegionStatistics s
    ->   ON r.RegionCode = s.RegionCode
    ->  AND r.BoundaryYear = s.BoundaryYear
    -> WHERE r.RegionLevel = 'Buurt'
    ->   AND s.StatisticsYear = 2025
    ->   AND s.RentalSharePct IS NOT NULL
    -> ORDER BY s.RentalSharePct DESC, r.RegionCode
    -> LIMIT 10;
+----------------------------------+---------------+----------------+
| RegionName                       | DwellingCount | RentalSharePct |
+----------------------------------+---------------+----------------+
| Utrecht Science Park             |          1707 |         99.000 |
| Bedrijvengebied Kanaleneiland    |           372 |         97.000 |
| Neckardreef en omgeving          |          2247 |         89.000 |
| Sterrenwijk                      |           392 |         88.000 |
| Transwijk-Zuid                   |          2001 |         87.000 |
| Hoog-Catharijne NS en Jaarbeurs  |          1198 |         86.000 |
| Plettenburg                      |           303 |         86.000 |
| Wolga- en Donaudreef en omgeving |          2164 |         85.000 |
| Kanaleneiland-Noord              |          4118 |         84.000 |
| Zambesidreef en omgeving         |          2050 |         83.000 |
+----------------------------------+---------------+----------------+
The query returned the ten neighbourhoods with the highest rental housing shares in the selected CBS data. Utrecht Science Park ranked first
with 99% of its 1,707 dwellings classified as rental housing. Bedrijvengebied Kanaleneiland followed with 97%, and Neckardreef en omgevin
with 89%. Across the ten neighbourhoods, rental shares ranged from 83% to 99%

## Video Presentation:
[![Our presentation: ](https://i9.ytimg.com/vi/JVG7gYdjscE/mqdefault.jpg?sqp=COiVgNYG-oaymwEmCMACELQB8quKqQMa8AEB-AH-CYAC0AWKAgwIABABGGEgYShhMA8=&rs=AOn4CLCpOZsik65oLXuGPmIVFaNoXx_blQ)](https://youtu.be/JVG7gYdjscE)
