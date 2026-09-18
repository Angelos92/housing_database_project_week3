# housing_database_project_week3
The responsitory contains our group project for the KEN2110 Database course.

The goal of the project is to design and implement a relational database based on our housing crising as social problem.

## A possible Responistory Stucture
- `sql/` → SQL files for schema creation, mock data, and queries
- `src/` → code used to interact with the database
- `docs/` → ERD, relational schema, and other documentation

## How to work on the Responsitory
1. Clone the repository:
   ```bash
   git clone <repository-link>

## Important
   - Always run "git pull" before starting work.
   - Do not overwrite someone else's changes.
   - Use clear commit messages.
   - Let the team know what file you are working on to avoid conflicts.

## Tasks
   - Convert ERD into relational schema
   - implement SQL tables and constrain
   - add mock data
   - add advanced SQL queries
   - Add code for database interaction

## Advance SQL Queries
Three advance SQL queries were written to demostrate multi-table joins, aggregation, anti-joins and derived tables. they can be found in ['advance_queries.sql'](./advance_queries.sql) and can be run directly against the populated database (after 'schema.sql' and 'mock_data.sql').

### 1. Average rental price per city
**Purpose:** Show the average listing price per city, usfule for comparing rental market across cities, Cities with only one listing are excluded so a single outlier doesn't skew the average.
**Techinques:** multi-table 'JOIN'. 'GROUP BY', 'HAVING'.

### 2. Housing types with no active listing
**Purpose:** Identify housing Types (e.g "studio", "apartment", "Townhouse") that currently have no listing in the database at all - usful for spotting gaps in the catalogue or used reference data.
**Techinque:** anti-joim pattern using 'NOT EXISTS' with a correlated subquery.

### 3. Listing priced below average for their housing type
**purpose:** SUrface listing that are cheaper than the average for their own housing type - a simple way to highlight potential "good deals" for users browsing the platform. The average is computed once per housing type in a derived table and joined back, so it's shown directly alongside each price rather than hidden inside the filter condition.
**Technique:** derived table (subquery in 'FROM'), 'JOIN', 'GROUP BY', computed column.
