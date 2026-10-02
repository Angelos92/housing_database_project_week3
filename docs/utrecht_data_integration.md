# Utrecht and CBS

The selected files are `Datasets/A/utrechthousingsmall.csv` and `Datasets/B/kwb2025.xlsx`.

## Findings and exact scope

| Source | Data rows read | Selected | Accepted | Rejected | Explicitly outside scope |
| --- | ---: | ---: | ---: | ---: | ---: |
| Utrecht housing CSV | 100 | 100 | 100 | 0 | 0 |
| CBS workbook | 18,495 | 122 | 122 | 0 | 18,373 |

The profile covers missing markers and input types across all CBS columns, with detailed per-column ranges and values for the selected Utrecht rows. Domain validation applies to the fields promoted into typed analytical tables - unselected analytical columns remain in the raw source audit payload.

## Cleaning performed and why

| Issue | Observed evidence | Treatment |
| --- | --- | --- |
| Missing Utrecht data | No missing values in any of the 17 CSV fields | No imputation, row deletion or substitution. |
| Missing selected CBS fields | `g_wozbag`: 5 dots; each of `p_huurw`, `p_wcorpw`, `p_ov_hw`: 3 dots | **14 dot-to-NULL conversions.** Unknown/unreliable/suppressed values are not zeros. Original dot and field name are retained in the audit. |
| CBS postcode blanks | 11 blanks: municipality and district rows | **11 blank-to-NULL conversions.** A neighbourhood-level dominant postcode is not available for these rows. Blank and dot reasons are recorded separately. |
| Other CBS missing values | Many other columns have blank/dot values, profiled in the JSON report | Preserve their original values in RawValues. Do not pretend all 124 workbook columns were promoted to analytical measures. |
| Whitespace/names | No surrounding whitespace in the selected `regio`, `gm_naam`, `recs` values | Trimming is supported; no actual name replacement was needed. Preserve spelling and Unicode. Short SQL column names replace hyphens in code, not values in source files. |
| Duplicate identifiers | None in either source | Primary/unique keys prevent future duplicate inserts. Future duplicate CSV IDs quarantine every occurrence for review, rather than arbitrarily keeping the first. |
| Dates | CSV has `buildyear` only, 1926–2017; selected fields contain no full dates | Store as SMALLINT, not a fabricated January 1 date. CBS statistics and boundary years are 2025. No publication or retrieval date inferred from file timestamps. |
| Decimal areas | `house-area` ranges 68.85–245.25; several fields have fractional values | Use exact Decimal parsing and DECIMAL storage, not Week 3's integer SizeM2. No rounding or truncation. |
| Lot arithmetic | Maximum absolute difference between `lot-len * lot-width` and `lot-area` is 0.05 | Consistent with possible source rounding. Preserve reported area; do not overwrite it with the product. House area larger than lot area is not automatically an error. |
| Identifiers/postcodes | Six-digit CSV IDs and four-character postcodes | Preserve as text. CSV IDs are source-specific, not BAG identifiers. The four-digit postcode is a prefix, not a complete street address. |
| Coded attributes | `balcony`: 0–2; `energy-eff`, `monument`: 0–1; `select`: 0–10 | Preserve as integer source codes. Do not interpret balcony as Boolean, energy-eff as an energy certificate, or select as an inclusion flag. **All select values are retained.** |
| Unexpected numeric inputs | No nonnumeric inputs in the supplied CSV; dot/blank CBS cells occur in otherwise numeric fields | Validate finite numbers, integer fields, precision and ranges. A malformed selected value is quarantined with its source row and reason. Import stops on rejects unless the user explicitly chooses `--allow-rejected`. |

The cleaner records **25 actual missing-value conversions** in `quality_report.json`. 
Decimal fields are serialized as strings in the intermediate JSON to preserve precision, then inserted into MySQL DECIMAL columns. 
RawValues retains the original cell values separately. The typed schema accepts NULL for unavailable attributes, not artificial zeros.

## Units and location: unresolved metadata preserved honestly

The CSV does not supply units, currency, a coordinate reference system or definitions for its coded attributes. Until a codebook confirms these:

- MeasurementDefinition.UnitName stays NULL for the seven source measures. Taxvalue and retailvalue are preserved as numeric source values, **not rental prices**, verified sale transactions or EUR amounts.
- Coordinates range X=2000–2969 and Y=5006–5968. Retain them as source coordinates with CoordinateSystem NULL. Do not assume latitude/longitude or Dutch RD coordinates.
- Keep City, Street and neighbourhood link NULL. The filename is not enough to validate the address of each property. The CSV has postcode values 3500 (19 rows), 3800 (32), 3525 (24) and 3528 (25).
- CBS's `pst_mvp` is a dominant four-digit postcode for a neighbourhood, not an exact address-to-neighbourhood mapping. Two selected CBS neighbourhoods have dominant postcode 3525. Even a unique dominant-postcode match is insufficient to prove a property's neighbourhood. **No property-to-CBS geographic match is invented.**

CBS's documented `g_wozbag` unit is thousands of euros. It stays in that unit as AverageWozThousandsEUR; no multiplication or interpretation as monthly rent is performed. Its 2025 valuation reference is 1 January 2024 according to the supplied CBS manual. Ownership measures are percentages of dwellings, not landlord identities; corporation ownership is not a guarantee of social rent. Population, households and dwellings are counts. Percentage constraints allow NULL or values from 0 through 100, without demanding that rounded ownership shares add to exactly 100.

The files can be imported independently now. A trustworthy combined neighbourhood query requires a source mapping or a documented coordinate transformation and boundary match later. This is a real limitation, not an import failure.

## Revised schema compared with Week 3

The implemented revision is [sql/real_data_schema.sql](../sql/real_data_schema.sql). Original `schema.sql` and `mock_data.sql` remain Week 3 history. **Do not run them in the new database:** the original script drops tables and its mock inserts target a different schema.

| Week 3 concept | Implemented change and reason |
| --- | --- |
| Location required street, full postcode, city and neighbourhood | Location now allows missing address details, stores PostalCodePrefix as CHAR(4), decimal source coordinates and nullable CRS, and an optional year-specific Region FK. All imported neighbourhood links remain NULL. |
| Property required HousingTypeId | HousingTypeId is nullable. No source establishes room/studio/apartment, so no category is invented. |
| Property.SizeM2 was an integer | Replaced by PropertyMeasurement plus MeasurementDefinition. Seven measures retain fractional values and explicit nullable units. This avoids claiming that unverified units are square metres. |
| Property had only a local key | Retain PropertyId, add source row FK and UNIQUE(DatasetId, ExternalId). BuildYear and Bathrooms use checked integer types. |
| No source-code support | PropertySourceAttribute stores the four original codes; SourceAttributeDefinition describes their source labels without inventing category labels. |
| No CBS regional entities | Region stores year-specific municipality/district/neighbourhood identities and parent FKs. RegionStatistics stores eight selected housing/population/postcode fields, statistics year and source-row FK. |
| No provenance or rejection evidence | SourceDataset stores file hashes and total/selected/excluded counts. SourceRecord preserves all 17 CSV or 124 CBS source fields for every selected record, acceptance status and rejection reason. |
| Listing and landlord entities | Listing, Landlord, LandlordType and RentalStatus are retained but empty. No rental prices, landlords or availability are fabricated. |

Every FK has MySQL's default restrictive behavior; the import never disables FK checks. Checks enforce nonnegative measures/counts, valid percentage ranges, build-year bounds and paired geographic-link fields. Identifiers and source-row keys are unique where their meaning requires it. Candidate unverified neighbourhood links are not stored.

### Normalization



## Reproduce cleaning and import

From the project folder in terminal/PowerShell:

```powershell
.\scripts\import_utrecht.ps1
```

This locates Python, installs missing dependencies into an ignored local folder if needed. Defaults are root, localhost:3306, database **housing_utrecht**. Change them as necessary:

```powershell
.\scripts\import_utrecht.ps1 -User your_username -Database housing_utrecht -Server localhost -Port 3306
```

If PowerShell blocks the unsigned local script, run this one-process invocation (no permanent policy change):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import_utrecht.ps1
```

The MySQL user needs CREATE DATABASE/TABLE, SELECT and INSERT permission. MySQL 8.0.16 or later is required for enforced checks.


## Row and content verification

**Regular-server import completed:** database `housing_utrecht`**. All 15 table-content checks passed, with 100 accepted properties and 122 accepted CBS records, zero rejects, and no accepted source records lost. The generated [import_report.json](../output/real_data/import_report.json) records the real server, counts, source hashes and content verification.


Expected counts:

| Table | Rows |
| --- | ---: |
| SourceDataset | 2 |
| SourceRecord | 222 |
| Location / Property | 100 each |
| MeasurementDefinition / PropertyMeasurement | 7 / 700 |
| SourceAttributeDefinition / PropertySourceAttribute | 4 / 400 |
| Region / RegionStatistics | 122 each |
| HousingType, RentalStatus, LandlordType, Landlord, Listing | 0 each |


In MySQL terminal after importing:

```sql
USE housing_utrecht;
SOURCE sql/verify_real_data.sql;
```

The original rental queries remain unsupported because Listing and Landlord have no source records.