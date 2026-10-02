"""Profile and clean the selected Utrecht CSV and CBS XLSX without editing either.

Writes typed, importable JSON plus full raw selected records, changes, rejects and
counts. This is a database ETL artifact, not a replacement Excel workbook.
"""
import argparse
import csv
import hashlib
import json
import re
from collections import Counter
from decimal import Decimal, InvalidOperation
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/real_data'
MEASURES = {
    'lot-len': 'Lot length as supplied', 'lot-width': 'Lot width as supplied',
    'lot-area': 'Lot area as supplied', 'house-area': 'House area as supplied',
    'garden-size': 'Garden size as supplied', 'taxvalue': 'Tax value as supplied',
    'retailvalue': 'Retail value as supplied; not a rent or verified transaction price',
}
ATTRIBUTES = {
    'balcony': 'Uninterpreted balcony code; observed 0, 1, 2',
    'energy-eff': 'Uninterpreted energy efficiency code; not an energy label',
    'monument': 'Uninterpreted monument code',
    'select': 'Uninterpreted selection code; never used as a row filter',
}
CBS = {
    'a_inw': ('Population', True, None), 'a_hh': ('Households', True, None),
    'a_woning': ('DwellingCount', True, None),
    'g_wozbag': ('AverageWozThousandsEUR', False, None),
    'p_huurw': ('RentalSharePct', False, 100),
    'p_wcorpw': ('CorporationSharePct', False, 100),
    'p_ov_hw': ('OtherLandlordSharePct', False, 100),
}


def text(v):
    return '' if v is None else str(v).strip()


def missing(v):
    return 'blank' if text(v) == '' else ('dot' if text(v) == '.' else None)


def number(v, integral=False, maximum=None, precision=4):
    if missing(v):
        return None
    try:
        n = Decimal(text(v))
    except InvalidOperation:
        raise ValueError(f'Non-numeric value: {v!r}') from None
    if not n.is_finite() or n < 0 or (maximum is not None and n > maximum):
        raise ValueError(f'Out-of-range number: {v!r}')
    if n >= Decimal('100000000000000') or n != n.quantize(Decimal(10) ** -precision):
        raise ValueError(f'Value exceeds storage precision: {v!r}')
    if integral:
        if n != n.to_integral_value():
            raise ValueError(f'Expected integer: {v!r}')
        return int(n)
    return format(n, 'f')


def hash_file(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def profile(rows):
    result = {}
    for column in rows[0] if rows else []:
        values = [r[column] for r in rows]
        numeric, bad = [], []
        for v in values:
            if missing(v):
                continue
            try:
                n = Decimal(text(v))
                if n.is_finite():
                    numeric.append(n)
                else:
                    bad.append(text(v))
            except InvalidOperation:
                bad.append(text(v))
        counts = Counter(text(v) for v in values)
        result[column] = {
            'blank': sum(missing(v) == 'blank' for v in values),
            'dot': sum(missing(v) == 'dot' for v in values),
            'python_types': dict(Counter(type(v).__name__ for v in values)),
            'whitespace_values': sum(isinstance(v, str) and v != v.strip() for v in values),
            'unique_values': len(counts),
            'values': dict(counts) if len(counts) <= 15 else None,
            'numeric_min': str(min(numeric)) if numeric else None,
            'numeric_max': str(max(numeric)) if numeric else None,
            'non_numeric_examples': list(dict.fromkeys(bad))[:5],
        }
    return result


def prepare(csv_path, xlsx_path):
    tables = {k: [] for k in (
        'SourceDataset', 'SourceRecord', 'Region', 'RegionStatistics', 'Location',
        'HousingType', 'Property', 'MeasurementDefinition', 'PropertyMeasurement',
        'SourceAttributeDefinition', 'PropertySourceAttribute', 'RentalStatus',
        'LandlordType', 'Landlord', 'Listing')}
    changes, rejected = [], []

    def raw_record(dataset, rownum, identifier, raw):
        record = dict(DatasetId=dataset, SourceRow=rownum, SourceIdentifier=identifier,
                      RawValues=raw, RecordStatus='accepted', RejectionReason=None)
        tables['SourceRecord'].append(record)
        return record

    def reject(record, reason):
        record['RecordStatus'] = 'rejected'
        record['RejectionReason'] = str(reason)
        rejected.append({'dataset': record['DatasetId'], 'row': record['SourceRow'],
                         'identifier': record['SourceIdentifier'], 'reason': str(reason)})

    def numeric(dataset, rownum, key, value, **kwargs):
        cleaned = number(value, **kwargs)
        reason = missing(value)
        if reason:
            changes.append(dict(dataset=dataset, row=rownum, field=key, raw=value,
                                cleaned=None, reason=f'{reason} marker converted to NULL'))
        elif isinstance(value, str) and value != value.strip():
            changes.append(dict(dataset=dataset, row=rownum, field=key, raw=value,
                                cleaned=cleaned, reason='Trim surrounding whitespace'))
        return cleaned

    with csv_path.open(encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f)
        expected = {'id','zipcode','x-coor','y-coor','buildyear','bathrooms'} | set(MEASURES) | set(ATTRIBUTES)
        if set(reader.fieldnames or []) != expected:
            raise ValueError('Unexpected Utrecht CSV columns; update mapping before importing.')
        houses = list(reader)
    id_counts = Counter(text(r['id']) for r in houses)
    for offset, r in enumerate(houses, 2):
        key = text(r['id'])
        raw = raw_record('utrecht', offset, key, r)
        try:
            if not re.fullmatch(r'\d{1,50}', key):
                raise ValueError('Missing/invalid source identifier')
            if id_counts[key] != 1:
                raise ValueError('Duplicate identifier; all conflicting occurrences quarantined')
            postcode = text(r['zipcode']) or None
            if postcode and not re.fullmatch(r'\d{4}', postcode):
                raise ValueError('Expected four-character source postcode, not a full address')
            vals = {k: numeric('utrecht', offset, k, r[k]) for k in MEASURES}
            codes = {k: numeric('utrecht', offset, k, r[k], integral=True, maximum=2147483647) for k in ATTRIBUTES}
            build = numeric('utrecht', offset, 'buildyear', r['buildyear'], integral=True, maximum=9999)
            if build is not None and build < 1000:
                raise ValueError('Invalid four-digit build year; do not treat as full date')
            baths = numeric('utrecht', offset, 'bathrooms', r['bathrooms'], integral=True, maximum=32767)
            x = numeric('utrecht', offset, 'x-coor', r['x-coor'])
            y = numeric('utrecht', offset, 'y-coor', r['y-coor'])
        except (ValueError, TypeError) as e:
            reject(raw, e)
            continue
        pid = offset - 1
        tables['Location'].append(dict(LocationId=pid, Street=None, PostalCodePrefix=postcode,
            City=None, XCoordinate=x, YCoordinate=y, CoordinateSystem=None,
            NeighborhoodBoundaryYear=None, NeighborhoodCode=None))
        tables['Property'].append(dict(PropertyId=pid, DatasetId='utrecht', SourceRow=offset,
            ExternalId=key, LocationId=pid, HousingTypeId=None, BuildYear=build, Bathrooms=baths))
        for k, v in vals.items():
            if v is not None:
                tables['PropertyMeasurement'].append(dict(PropertyId=pid, MeasureCode=k, NumericValue=v))
        for k, v in codes.items():
            if v is not None:
                tables['PropertySourceAttribute'].append(dict(PropertyId=pid, AttributeCode=k, SourceCode=v))
    tables['MeasurementDefinition'] = [dict(MeasureCode=k, Description=v, UnitName=None) for k,v in MEASURES.items()]
    tables['SourceAttributeDefinition'] = [dict(AttributeCode=k, Description=v) for k,v in ATTRIBUTES.items()]

    selected, cbs_ids, levels, total, all_missing, full_types = [], Counter(), Counter(), 0, Counter(), {}
    workbook = openpyxl.load_workbook(xlsx_path, read_only=True, data_only=True)
    sheet = workbook.worksheets[0]
    rows = iter(sheet.values)
    headers = [text(v) for v in next(rows)]
    if not {'gwb_code_10','regio','gm_naam','recs','pst_mvp'} | set(CBS) <= set(headers):
        raise ValueError('Expected CBS header columns not found')
    for rownum, values in enumerate(rows, 2):
        if all(v is None for v in values):
            continue
        r = dict(zip(headers, values)); total += 1
        cbs_ids[text(r['gwb_code_10'])] += 1
        levels[text(r['recs'])] += 1
        for k,v in r.items():
            if missing(v): all_missing[k] += 1
            full_types.setdefault(k, Counter())[type(v).__name__] += 1
        if text(r['gm_naam']) == 'Utrecht':
            selected.append((rownum,r))
    workbook.close()
    for rownum, r in selected:
        code = text(r['gwb_code_10'])
        raw = raw_record('cbs2025', rownum, code, r)
        try:
            if cbs_ids[code] != 1:
                raise ValueError('Duplicate CBS code in source workbook')
            level = text(r['recs'])
            patterns = {'Gemeente': r'GM0344', 'Wijk': r'WK0344[A-Z0-9]{2}', 'Buurt': r'BU0344[A-Z0-9]{4}'}
            if level not in patterns or not re.fullmatch(patterns[level], code):
                raise ValueError('Unexpected Utrecht CBS code/level')
            vals = {column: numeric('cbs2025',rownum,k,r[k],integral=integral,
                    maximum=maximum if maximum is not None else (2147483647 if integral else None),precision=3)
                    for k,(column,integral,maximum) in CBS.items()}
            pc = numeric('cbs2025',rownum,'pst_mvp',r['pst_mvp'],integral=True,maximum=9999)
            pc = str(pc).zfill(4) if pc is not None else None
        except (ValueError,TypeError) as e:
            reject(raw,e); continue
        parent = None if level == 'Gemeente' else ('GM0344' if level=='Wijk' else 'WK'+code[2:8])
        tables['Region'].append(dict(BoundaryYear=2025, RegionCode=code, RegionName=text(r['regio']),
                                    RegionLevel=level, ParentCode=parent))
        tables['RegionStatistics'].append(dict(BoundaryYear=2025,RegionCode=code,StatisticsYear=2025,
            DatasetId='cbs2025',SourceRow=rownum,**vals,DominantPostalCode=pc))
    tables['Region'].sort(key=lambda r: ({'Gemeente':0,'Wijk':1,'Buurt':2}[r['RegionLevel']],r['RegionCode']))
    region_keys = {r['RegionCode'] for r in tables['Region']}
    if any(r['ParentCode'] and r['ParentCode'] not in region_keys for r in tables['Region']):
        raise ValueError('Missing accepted CBS parent region; fix rejected parent before import')
    for dataset,path,count,chosen in [('utrecht',csv_path,len(houses),len(houses)),('cbs2025',xlsx_path,total,len(selected))]:
        tables['SourceDataset'].append(dict(DatasetId=dataset,FileName=path.name,Sha256=hash_file(path),
            TotalRows=count,SelectedRows=chosen,ExcludedRows=count-chosen))
    counts = {}
    for dataset in ('utrecht','cbs2025'):
        records=[r for r in tables['SourceRecord'] if r['DatasetId']==dataset]
        counts[dataset] = dict(selected=len(records),accepted=sum(r['RecordStatus']=='accepted' for r in records),
                               rejected=sum(r['RecordStatus']=='rejected' for r in records))
        assert counts[dataset]['selected']==counts[dataset]['accepted']+counts[dataset]['rejected']
    by_property = {}
    for measure in tables['PropertyMeasurement']:
        by_property.setdefault(measure['PropertyId'], {})[measure['MeasureCode']] = Decimal(measure['NumericValue'])
    lot_differences = [abs(m['lot-len']*m['lot-width']-m['lot-area']) for m in by_property.values()
                       if {'lot-len','lot-width','lot-area'} <= m.keys()]
    return dict(tables=tables, reconciliation=counts, changes=changes, rejected=rejected,
        profile=dict(utrecht=profile(houses),cbs_utrecht=profile([r for _,r in selected]),
            cbs_total_rows=total,cbs_region_levels=dict(levels),
            cbs_duplicate_ids={k:v for k,v in cbs_ids.items() if v>1},
            cbs_missing_all_columns=dict(all_missing),
            cbs_types_all_columns={k:dict(v) for k,v in full_types.items()},
            ut_source_duplicate_ids={k:v for k,v in id_counts.items() if v>1},
            ut_exact_duplicate_rows=len(houses)-len({tuple(r.items()) for r in houses}),
            lot_area_max_difference=str(max(lot_differences)) if lot_differences else None),
        limitations=['Utrecht units, coordinate reference system and code meanings unconfirmed',
            'No property-to-CBS neighbourhood matching inferred from four-digit postcode',
            'CBS selected analytical fields typed; all other selected-row fields retained in RawValues',
            'Teammate supplies publication dates, licenses and source documentation'])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv',type=Path,default=ROOT/'Datasets/A/utrechthousingsmall.csv')
    parser.add_argument('--cbs',type=Path,default=ROOT/'Datasets/B/kwb2025.xlsx')
    args=parser.parse_args()
    result=prepare(args.csv,args.cbs)
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'cleaned.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'quality_report.json').write_text(json.dumps({k:v for k,v in result.items() if k!='tables'},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result['reconciliation'],indent=2))
    print('Table counts:',{k:len(v) for k,v in result['tables'].items()})
    print('Outputs:',OUT)


if __name__=='__main__':
    main()
