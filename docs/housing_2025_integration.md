# 2025 housing CSV and CBS: current import

`Datasets/A/2025-housing-dataset-alldata.csv` and `Datasets/B/kwb2025.xlsx`.

Source, license and publication date:

Dataset A:

Source: https://www.kaggle.com/datasets/ictinstitute/utrecht-housing-dataset/data

Publication date: 1-2-2025

The dataset is released as creative commons, and can be used freely for any purpose. If you use it, please refer to it as the “The Utrecht housing dataset – example dataset for prediction” by Sieuwert van Otterloo, www.ictinstitute.nl or refer to Sieuwert van Otterloo as the author/source.

Dataset B:

Source: https://www.cbs.nl/nl-nl/maatwerk/2026/26/kerncijfers-wijken-en-buurten-2025

Publication date: 18-9-2026 

Unless otherwise stated, the Creative Commons Attribution (CC BY 4.0 ) applies to the content of this website.

## Cleaning and scope

The CSV contains **153 records, 23 columns and 153 unique IDs**, with no rejected records. Gaps in identifiers are not missing rows to manufacture.

| Finding | What we did and why |
| --- | --- |
| Garden size: 10 `Unspecified`, two blank | Left these sizes unknown. An unknown garden size does not mean the garden has an area of zero. |
| Energy label and efficiency: three `Unspecified` each | Left these values unknown. Used NULL (meaning missing) for the label and left out the missing efficiency value. |
| 39 street names with extra spaces at the start or end | Removed the extra spaces so the names are stored consistently. |
| Zero lot/garden areas, including apartments | Kept the zeros because they were actual values in the file. |
| House types | Added `appartement` and `woonhuis` to HousingType and assigned each property its source type. |
| Full postcodes and four-digit prefixes | Checked that the first four digits matched. All matched, so we kept the full postcode. |
| `zipcode6id` | Kept this code as SourceAddressId. |
| Valuation dates | Checked and stored the dates in year-month-day format. They range from 2024-01-31 to 2024-11-27. |
| Construction year 1320 | Kept the year as supplied. Used SMALLINT, an integer type that can store years this old. |
| Asking/retail values | Kept both values separately and unchanged. Their units still need confirmation, and they are not monthly rents. |
| Coordinates | Kept the x/y values unchanged. |
| District/subdistrict | Kept the district names, but have not yet checked which CBS areas they match. |

The original values are kept in SourceRecord, and cleaning changes are recorded so they can be checked later.

There are **18 housing missing-value transformations and 39 street trims**. Six measurements are loaded: lot-area, house-area, garden-size, retailvalue, askingprice and dist-from-train. Units remain NULL pending a codebook. `energy-eff` - its 0/1 code is distinct from the supplied energy label.

Source city labels: Utrecht (128), Nieuwegein (8), Vleuten (15), De Meern (2). No houses are excluded. CBS selection includes municipality names **Utrecht and Nieuwegein**: **184 records, comprising two municipalities, 32 districts and 150 neighbourhoods**. This adds 62 Nieuwegein records. It does not establish individual property-to-region links; those remain NULL.

Selected CBS analytical fields contain 58 dot markers and 34 blanks, converted to NULL with distinct audit reasons. All other source fields remain in RawValues. Do not sum municipality, district and neighbourhood totals together. The 2025 CBS WOZ field remains in its documented thousands-of-euros unit (it is not a rental price).

## Schema and process changes

- Location.PostalCode replaces PostalCodePrefix. 
- Property gains Rooms, EnergyLabel, ValuationDate (DATE) and SourceAddressId. HousingTypeId points to the populated lookup.
- SourceRecord retains all 23 source columns. DatasetId is `housing2025`.
- Cleaned data uses schema version `housing2025-v1`, the importer rejects incompatible prepared data before connecting.
- MySQL DATE values are canonicalized to ISO strings during content verification. Decimal-padding normalization remains in place.
- Outputs now go to **output/housing_2025/**, historical output/real_data results are untouched.

Use [real_data_schema.sql](../sql/real_data_schema.sql) only in a fresh database. This is not an ALTER migration for the old database. Keys, foreign keys, checks, transaction rollback and refusal to overwrite nonempty databases remain active. Rental Listing and Landlord tables remain empty.

## Run on your MySQL server

The launcher retains its existing filename for compatibility. From the project root:

```powershell
.\scripts\import_utrecht.ps1
```

The default is **housing_2025**, root, localhost:3306. Enter the password privately. Override as necessary:

```powershell
.\scripts\import_utrecht.ps1 -User your_username -Database housing_2025
```

Use an empty database. For a repeat load choose a new database name; existing tables are never dropped. With a separately configured Python environment, run `python scripts/prepare_real_data.py` then `python scripts/import_real_data.py --database housing_2025 --user root`.

After importing in MySQL:

```sql
USE housing_2025;
SOURCE sql/verify_real_data.sql;
```

`cleaned.json` is the import input, `quality_report.json` is cleaning evidence, and `import_report.json` identifies the actual imported database. All row counts and contents must match before commit. Missing measurements have no measurement row; the property and raw source record remain present.

## Validation performed

A full import succeeded on a separate **MySQL 9.2.0 test instance**, database `housing_2025_validation`. All 15 table-content comparisons passed. The regular password-protected server has **not** been updated by this code-change task.

| Entity | Verified rows |
| --- | ---: |
| Housing source records / properties / locations | 153 each |
| CBS source records / regions / statistics | 184 each |
| All raw source records | 337 |
| Housing types | 2 |
| Measurement definitions / measurements | 6 / 906 |
| Attribute definitions / attributes | 1 / 150 |
| Listings / landlords | 0 / 0 |

CBS reconciliation: 18,495 = 184 selected + 18,311 explicitly outside scope. Housing reconciliation: 153 selected = 153 accepted + zero rejected. SQL found **zero accepted source records without their operational entity**.

Six automated tests passed: missing versus zero, numerical validation, dates/postcodes, MySQL DATE/DECIMAL comparisons, complete real-file reconciliation, new fields, housing types, old construction years, and no fabricated listings or geographic matches. Run `python -m unittest discover -s tests -v`. Test evidence: `output/housing_2025/validation_import_report.json`.

The three original Week 3 queries were rerun on the new test database. Queries 1 and 3 return no rental listings. Query 2 now returns **appartement and woonhuis** because source housing types exist but rental listings do not. Earlier README outputs describe the old dataset and should be labelled historical when the team updates its report. This is a coverage limitation, not proof of no rentals.

Query 4: Which neighbourhoods have the highest rental shares?

The query returned the ten neighbourhoods with the highest rental housing shares in the selected CBS data. Utrecht Science Park ranked first, with 99% of its 1,707 dwellings classified as rental housing. Bedrijvengebied Kanaleneiland followed with 97%, and Neckardreef en omgeving with 89%. Across the ten neighbourhoods, rental shares ranged from 83% to 99%
