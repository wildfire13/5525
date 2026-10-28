import copy
from contextlib import closing
import json
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from master_data import ROOT, build, read, runtime_probe

class MasterTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.temp.name)
        self.source=json.loads((ROOT/'master-source.json').read_text())
        self.src=self.root/'source.json';self.db=self.root/'master.sqlite'
        self.write()
    def tearDown(self):self.temp.cleanup()
    def write(self):
        self.src.write_text(json.dumps(self.source));build(self.src,self.db)
    def test_roundtrip(self):
        actual=read(self.db);actual.pop('grantsByEquipment');self.assertEqual(actual,self.source)
    def test_deterministic(self):
        original=self.db.read_bytes();self.write();self.assertEqual(original,self.db.read_bytes())
    def test_read_does_not_write(self):
        original=self.db.read_bytes();read(self.db);self.assertEqual(original,self.db.read_bytes())
    def test_flavor_roundtrip_and_type_validation(self):
        self.source['gear'][0]['flavor']='既存の原稿。'
        self.write()
        self.assertEqual(read(self.db)['gear'][0]['flavor'],'既存の原稿。')
        self.source['gear'][0]['flavor']={'not':'text'}
        with self.assertRaises(ValueError):self.write()
    def test_missing_and_corrupt(self):
        with self.assertRaises(ValueError):read(self.root/'absent.sqlite')
        self.db.write_bytes(b'not a database')
        with self.assertRaises(sqlite3.DatabaseError):read(self.db)
    def test_foreign_key_corruption(self):
        with closing(sqlite3.connect(self.db)) as db, db:db.execute("UPDATE equipment_skill SET skill_id='missing'")
        with self.assertRaises(ValueError):read(self.db)
    def test_duplicate_grants_preserved(self):
        with closing(sqlite3.connect(self.db)) as db, db:
            db.execute('PRAGMA foreign_keys=ON')
            row=db.execute("SELECT equipment_id,skill_id,level,source_field,explicit_level FROM equipment_skill WHERE equipment_id='kungfu-pants'").fetchone()
            db.execute('INSERT INTO equipment_skill VALUES(?,2,?,?,?,?)',row)
        grants=read(self.db)['grantsByEquipment']['kungfu-pants'];self.assertEqual(len(grants),2);self.assertEqual(grants[0]['id'],grants[1]['id'])
    def test_bad_import_preserves_previous(self):
        original=self.db.read_bytes();self.source['gear'][0]['price']=-1;self.src.write_text(json.dumps(self.source))
        with self.assertRaises(ValueError):build(self.src,self.db)
        self.assertEqual(original,self.db.read_bytes())
    def test_unknown_skill_rejected(self):
        self.source['gear'][0]['skill']='unknown'
        with self.assertRaises(ValueError):self.write()
    def test_wrong_version(self):
        with closing(sqlite3.connect(self.db)) as db, db:
            db.execute('PRAGMA ignore_check_constraints=ON');db.execute('UPDATE metadata SET schema_version=99')
        with self.assertRaises(ValueError):read(self.db)
    def test_shadowed_fields(self):
        with closing(sqlite3.connect(self.db)) as db, db:db.execute('UPDATE equipment SET properties=? WHERE ordinal=0',(json.dumps({'price':99}),))
        with self.assertRaises(ValueError):read(self.db)
    def test_null_not_silently_zero(self):
        self.source['gear'][0]['price']=None
        with self.assertRaises(ValueError):self.write()
    def test_equipment_types_and_enums(self):
        pristine=copy.deepcopy(self.source)
        for field,value in [('atk','bad'),('hp',True),('reach',None),('agiBonus','-1'),('hands',3),('slot','unknown'),('type','unknown'),('allowedSlots',['weapon']),('starterOnly',1),('price',9007199254740992)]:
            with self.subTest(field=field):
                self.source=copy.deepcopy(pristine);self.source['gear'][0][field]=value
                with self.assertRaises(ValueError):self.write()
    def test_runtime_rejects_malformed_properties(self):
        for field,value in [('atk','bad'),('allowedSlots',['unknown']),('virtualDefault',1)]:
            with self.subTest(field=field):
                self.write()
                with closing(sqlite3.connect(self.db)) as db, db:
                    props=json.loads(db.execute('SELECT properties FROM equipment WHERE ordinal=0').fetchone()[0]);props[field]=value
                    db.execute('UPDATE equipment SET properties=? WHERE ordinal=0',(json.dumps(props),))
                with self.assertRaises(ValueError):read(self.db)
    def test_first_grant_keeps_its_level(self):
        # Later slots must not silently raise the level of the legacy first-slot projection.
        with closing(sqlite3.connect(self.db)) as db, db:
            db.execute('PRAGMA foreign_keys=ON')
            db.execute("INSERT INTO equipment_skill VALUES('kungfu-pants',2,'legSweep',3,'skill',1)")
        actual=read(self.db)
        gear=next(g for g in actual['gear'] if g['id']=='kungfu-pants')
        self.assertEqual(gear['skillLevel'],1)
        self.assertEqual([g['level'] for g in actual['grantsByEquipment']['kungfu-pants']],[1,3])
    def test_source_duplicate_grants_roundtrip(self):
        self.source['equipmentGrants'].append(dict(equipmentId='kungfu-pants',slotNo=2,id='legSweep',level=3,sourceField='skill',explicitLevel=True))
        # The canonical order is equipment order then grant slot.
        order={g['id']:i for i,g in enumerate(self.source['gear'])}
        self.source['equipmentGrants'].sort(key=lambda g:(order[g['equipmentId']],g['slotNo']))
        self.write()
        self.assertEqual(len(read(self.db)['grantsByEquipment']['kungfu-pants']),2)
    def test_runtime_rejects_invalid_skill_definition(self):
        with closing(sqlite3.connect(self.db)) as db, db:
            definition=json.loads(db.execute("SELECT definition FROM skill WHERE id='legSweep'").fetchone()[0]);definition['reach']='near'
            db.execute("UPDATE skill SET definition=? WHERE id='legSweep'",(json.dumps(definition),))
        with self.assertRaises(ValueError):read(self.db)
    def test_legacy_relation_does_not_consume_real_grant_slots(self):
        sword=next(g for g in self.source['gear'] if g['id']=='sword-wood')
        self.assertEqual(sword['legacySkill'],'guard')
        self.assertFalse(any(g['equipmentId']==sword['id'] for g in self.source['equipmentGrants']))
        sword['skill']='mage'
        for slot,skill in enumerate(['mage','stamp','knockback'],1):
            self.source['equipmentGrants'].append(dict(equipmentId=sword['id'],slotNo=slot,id=skill,level=1,sourceField='skill',explicitLevel=False))
        order={g['id']:i for i,g in enumerate(self.source['gear'])}
        self.source['equipmentGrants'].sort(key=lambda g:(order[g['equipmentId']],g['slotNo']))
        self.write();actual=read(self.db)
        self.assertEqual(next(g for g in actual['gear'] if g['id']==sword['id'])['legacySkill'],'guard')
        self.assertEqual([g['slotNo'] for g in actual['grantsByEquipment'][sword['id']]],[1,2,3])
        with closing(sqlite3.connect(self.db)) as db, db:
            self.assertEqual(db.execute('SELECT skill_id FROM equipment_legacy_skill WHERE equipment_id=?',(sword['id'],)).fetchone(),('guard',))
    def test_legacy_reference_corruption_rejected(self):
        with closing(sqlite3.connect(self.db)) as db, db:db.execute("UPDATE equipment_legacy_skill SET skill_id='missing'")
        with self.assertRaises(ValueError):read(self.db)
    def test_legacy_reference_cannot_be_a_real_grant(self):
        self.source['equipmentGrants'].append(dict(equipmentId='sword-wood',slotNo=1,id='guard',level=1,sourceField='legacySkill',explicitLevel=False))
        with self.assertRaises(ValueError):self.write()
    def tracked_connections(self, fail_insert=False):
        opened=[]
        real_connect=sqlite3.connect
        class TrackedConnection(sqlite3.Connection):
            closed=False
            def close(self):
                super().close();self.closed=True
            def execute(self, statement, *args, **kwargs):
                if fail_insert and statement.startswith('INSERT INTO metadata'):
                    raise sqlite3.OperationalError('injected write failure')
                return super().execute(statement,*args,**kwargs)
        def connect(*args,**kwargs):
            connection=real_connect(*args,**kwargs,factory=TrackedConnection)
            opened.append(connection);return connection
        return opened,connect
    def assert_connections_closed(self, opened):
        self.assertTrue(opened)
        for connection in opened:
            self.assertTrue(connection.closed)
            with self.assertRaises(sqlite3.ProgrammingError):connection.execute('SELECT 1')
    def test_success_closes_writer_and_reader_before_atomic_replace(self):
        opened,connect=self.tracked_connections()
        real_replace=pathlib.Path.replace
        def replace(path,target):
            self.assertEqual(len(opened),2)
            self.assert_connections_closed(opened)
            return real_replace(path,target)
        with patch('master_data.sqlite3.connect',side_effect=connect),patch.object(pathlib.Path,'replace',replace):
            build(self.src,self.db)
        self.assert_connections_closed(opened)
        opened.clear()
        with patch('master_data.sqlite3.connect',side_effect=connect):read(self.db)
        self.assertEqual(len(opened),1);self.assert_connections_closed(opened)
    def test_read_validation_failure_closes_connection(self):
        with closing(sqlite3.connect(self.db)) as db, db:
            db.execute('PRAGMA ignore_check_constraints=ON');db.execute('UPDATE metadata SET schema_version=99')
        opened,connect=self.tracked_connections()
        with patch('master_data.sqlite3.connect',side_effect=connect):
            with self.assertRaises(ValueError):read(self.db)
        self.assert_connections_closed(opened)
    def test_build_write_failure_closes_before_cleanup_and_preserves_previous(self):
        original=self.db.read_bytes();before=set(self.root.iterdir())
        opened,connect=self.tracked_connections(fail_insert=True)
        with patch('master_data.sqlite3.connect',side_effect=connect):
            with self.assertRaises(sqlite3.OperationalError):build(self.src,self.db)
        self.assert_connections_closed(opened)
        self.assertEqual(self.db.read_bytes(),original);self.assertEqual(set(self.root.iterdir()),before)
    def test_projection_failure_closes_both_connections_and_preserves_previous(self):
        original=self.db.read_bytes();before=set(self.root.iterdir())
        self.source['gear'][0]['skill']='mage';self.src.write_text(json.dumps(self.source))
        opened,connect=self.tracked_connections()
        with patch('master_data.sqlite3.connect',side_effect=connect):
            with self.assertRaises(ValueError):build(self.src,self.db)
        self.assertEqual(len(opened),2);self.assert_connections_closed(opened)
        self.assertEqual(self.db.read_bytes(),original);self.assertEqual(set(self.root.iterdir()),before)
    def test_runtime_probe_checks_dependencies_and_closes_connection(self):
        opened,connect=self.tracked_connections()
        with patch('master_data.sqlite3.connect',side_effect=connect):result=runtime_probe()
        self.assertTrue(result['python']);self.assertTrue(result['pillow']);self.assertTrue(result['sqlite'])
        self.assertEqual(len(opened),1);self.assert_connections_closed(opened)
    def test_probe_cli_from_path_with_spaces_without_a_database(self):
        folder=self.root/'runtime with spaces';folder.mkdir()
        script=folder/'master_data.py';script.write_bytes((ROOT.parent/'master_data.py').read_bytes())
        result=subprocess.run([sys.executable,'-X','utf8','-B',str(script),'probe'],capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(set(json.loads(result.stdout)),{'python','pillow','sqlite'})
        self.assertEqual(list(folder.iterdir()),[script],'probe must not create a DB or cache')
    def test_probe_cli_missing_pillow_reports_dependency_failure(self):
        # -S excludes site-packages; Pillow is a runtime requirement, not vendored.
        result=subprocess.run([sys.executable,'-S','-B',str(ROOT.parent/'master_data.py'),'probe'],capture_output=True,text=True,timeout=10)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,'');self.assertIn('runtime dependencies',result.stderr)
    def test_no_new_gear(self):
        self.assertEqual(len(read(self.db)['gear']),58)
if __name__=='__main__':unittest.main()
