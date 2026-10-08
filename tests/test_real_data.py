import importlib.util
import unittest
from pathlib import Path
from decimal import Decimal
from datetime import date

ROOT=Path(__file__).resolve().parents[1]

def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/f'{name}.py')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

cleaner=load('prepare_real_data')
importer=load('import_real_data')

class CleaningTests(unittest.TestCase):
    def test_missing_is_not_zero(self):
        for value in (None,'','  .  ','\u00a0','Unspecified',' unspecified '):
            self.assertIsNone(cleaner.number(value))
        self.assertEqual(cleaner.number('0',integral=True),0)

    def test_decimal_precision_and_invalid_values(self):
        self.assertEqual(cleaner.number('68.85'),'68.85')
        for value in ('NaN','Infinity','abc','-1','1.00001'):
            with self.assertRaises(ValueError): cleaner.number(value)
        with self.assertRaises(ValueError): cleaner.number('1.5',integral=True)
        with self.assertRaises(ValueError): cleaner.number('101',maximum=100)

    def test_mysql_decimal_padding_does_not_change_content(self):
        expected=[{'NumericValue':'68.85','ExternalId':'0012'}]
        actual=[{'NumericValue':Decimal('68.8500'),'ExternalId':'0012'}]
        self.assertEqual(importer.fingerprint(expected),importer.fingerprint(actual))
        actual[0]['ExternalId']='12'
        self.assertNotEqual(importer.fingerprint(expected),importer.fingerprint(actual))

    def test_dates_and_postcodes(self):
        self.assertEqual(cleaner.iso_date('2024-02-29'),'2024-02-29')
        for invalid in ('2023-02-29','01/02/2024','2024-2-1'):
            with self.assertRaises(ValueError): cleaner.iso_date(invalid)
        self.assertEqual(cleaner.postal_code('3544 mc','3544'),'3544MC')
        with self.assertRaises(ValueError): cleaner.postal_code('3544MC','3528')
        self.assertEqual(importer.fingerprint([{'ValuationDate':'2024-05-01'}]),
                         importer.fingerprint([{'ValuationDate':date(2024,5,1)}]))


class NewDatasetIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result=cleaner.prepare(ROOT/'Datasets/A/2025-housing-dataset-alldata.csv',
                                  ROOT/'Datasets/B/kwb2025.xlsx')

    def test_no_selected_records_lost(self):
        self.assertEqual(self.result['rejected'],[])
        self.assertEqual(self.result['reconciliation']['housing2025']['accepted'],153)
        self.assertEqual(self.result['reconciliation']['cbs2025']['accepted'],184)
        self.assertEqual(len(self.result['tables']['SourceRecord']),337)
        self.assertEqual({r['DatasetId'] for r in self.result['tables']['SourceRecord']},
                         {'housing2025','cbs2025'})

    def test_new_fields_and_missing_values(self):
        tables=self.result['tables']
        self.assertEqual(len(tables['PropertyMeasurement']),906)
        self.assertEqual(len(tables['PropertySourceAttribute']),150)
        self.assertEqual(sum(p['EnergyLabel'] is None for p in tables['Property']),3)
        self.assertEqual(min(p['BuildYear'] for p in tables['Property']),1320)
        self.assertEqual({r['TypeName'] for r in tables['HousingType']},{'woonhuis','appartement'})
        self.assertEqual({r['City'] for r in tables['Location']},{'Utrecht','Nieuwegein','Vleuten','De Meern'})
        self.assertTrue(all(r['NeighborhoodCode'] is None for r in tables['Location']))
        self.assertEqual(tables['Listing'],[])
        self.assertTrue(any(r['NumericValue']=='0' for r in tables['PropertyMeasurement']))

if __name__=='__main__': unittest.main()
