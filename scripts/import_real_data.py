"""Import prepared Utrecht/CBS data into a fresh MySQL database and verify every row.
"""
import argparse
import getpass
import hashlib
import json
import os
import re
from decimal import Decimal
from datetime import date, datetime
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/housing_2025'
DECIMAL_COLUMNS={'NumericValue','XCoordinate','YCoordinate','AverageWozThousandsEUR',
                 'RentalSharePct','CorporationSharePct','OtherLandlordSharePct'}


def canonical(row):
    row=dict(row)
    for key,value in row.items():
        if key in DECIMAL_COLUMNS and value is not None:
            row[key]=str(Decimal(str(value)).normalize())
        elif key=='RawValues' and isinstance(value,str):
            row[key]=json.loads(value)
        elif isinstance(value, (date,datetime)):
            row[key]=value.isoformat()
    return json.dumps(row,sort_keys=True,ensure_ascii=False,separators=(',',':'))


def fingerprint(rows):
    return hashlib.sha256('\n'.join(sorted(canonical(r) for r in rows)).encode('utf-8')).hexdigest()


def import_data(args, password):
    import mysql.connector
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,63}',args.database):
        raise ValueError('Invalid database name; use a letter followed by letters, digits or underscores.')
    data=json.loads((OUT/'cleaned.json').read_text(encoding='utf-8'))
    if data.get('schema_version') != 'housing2025-v1':
        raise ValueError('Prepared data has an incompatible schema version. Run prepare_real_data.py again.')
    if data['rejected'] and not args.allow_rejected:
        raise ValueError('Quarantined rows exist. Review quality_report.json before using --allow-rejected.')
    expected=data['tables']
    connection=mysql.connector.connect(host=args.host,port=args.port,user=args.user,
        password=password,charset='utf8mb4',autocommit=False,connection_timeout=10)
    cursor=connection.cursor(dictionary=True,buffered=True)
    try:
        cursor.execute('SELECT VERSION() AS version')
        version=cursor.fetchone()['version']
        match=re.match(r'(\d+)\.(\d+)\.(\d+)',version)
        if not match or tuple(map(int,match.groups()))<(8,0,16) or 'MariaDB' in version:
            raise ValueError('This schema requires MySQL 8.0.16+ with enforced CHECK constraints.')
        cursor.execute(f'CREATE DATABASE IF NOT EXISTS `{args.database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_bin')
        cursor.execute(f'USE `{args.database}`')
        cursor.execute('SHOW TABLES')
        if cursor.fetchall():
            raise ValueError('Database is not empty. Choose a fresh --database name; nothing will be dropped.')
        cursor.execute("SET SESSION sql_mode='STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ENGINE_SUBSTITUTION'")
        for statement in (ROOT/'sql/real_data_schema.sql').read_text(encoding='utf-8').split(';'):
            if statement.strip(): cursor.execute(statement)
        for table,rows in expected.items():
            if not rows: continue
            columns=list(rows[0])
            sql=f'INSERT INTO `{table}` ('+','.join(f'`{c}`' for c in columns)+') VALUES ('+','.join(['%s']*len(columns))+')'
            values=[tuple(json.dumps(r[c],ensure_ascii=False) if c=='RawValues' else r[c] for c in columns) for r in rows]
            for offset in range(0,len(values),500): cursor.executemany(sql,values[offset:offset+500])
        checks={}
        for table,rows in expected.items():
            cursor.execute(f'SELECT * FROM `{table}`')
            actual=cursor.fetchall()
            expected_hash=fingerprint(rows); actual_hash=fingerprint(actual)
            if len(actual)!=len(rows) or expected_hash!=actual_hash:
                raise ValueError(f'Content/count verification failed: {table}')
            checks[table]={'expected':len(rows),'actual':len(actual),'content_sha256':actual_hash,'passed':True}
        cursor.execute('SELECT COUNT(*) AS n FROM Location WHERE NeighborhoodCode IS NOT NULL')
        assert cursor.fetchone()['n']==0, 'Unverified neighbourhood links must remain NULL'
        connection.commit()
        report={'engine':'MySQL','server_version':version,'host':args.host,'port':args.port,
            'database':args.database,'reconciliation':data['reconciliation'],'tables':checks,
            'verified_before_commit':True,'source_files':expected['SourceDataset']}
        OUT.mkdir(parents=True,exist_ok=True)
        report_path=OUT/args.report
        report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        print('Committed and verified:',args.database)
        print(json.dumps(data['reconciliation'],indent=2))
        print('Import report:',report_path)
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close(); connection.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host',default='localhost')
    parser.add_argument('--port',type=int,default=3306)
    parser.add_argument('--user',default='root')
    parser.add_argument('--database',default='housing_2025')
    parser.add_argument('--allow-rejected',action='store_true')
    parser.add_argument('--report',default='import_report.json')
    args=parser.parse_args()
    if Path(args.report).name!=args.report:
        parser.error('--report must be a file name, not a path')
    password=os.environ.get('HOUSING_MYSQL_PASSWORD')
    if password is None:
        password=getpass.getpass(f'MySQL password for {args.user}@{args.host}:{args.port}: ')
    import_data(args,password)


if __name__=='__main__':
    main()
