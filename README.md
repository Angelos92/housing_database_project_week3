# housing_database_project_week3
The repository contains our group project for the KEN2110 Database course.

The goal is to design and implement a relational database that models the housing crisis in Amsterdam - tracking properties, their locations, housing types, landlords and rental listing status.

## Possible Repository Structure
- `sql/` → SQL files for schema creation, mock data, and queries
- `src/` → code used to interact with the database
- `docs/` → ERD, relational schema, and other documentation

## How to work on the Repository
1. Clone the repository:
   ```bash
   git clone <repository-link>

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