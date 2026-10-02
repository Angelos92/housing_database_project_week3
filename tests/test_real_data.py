import importlib.util
import unittest
from pathlib import Path
from decimal import Decimal

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
        for value in (None,'','  .  ','\u00a0'):
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

if __name__=='__main__': unittest.main()
