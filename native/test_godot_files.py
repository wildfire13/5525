import base64, errno, hashlib, json, os, tempfile, threading, unittest
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
import godot_files
from pathlib import Path
from godot_files import write_new, run, prepare_portraits
from portraits import read_raster
class GodotFilesTests(unittest.TestCase):
    def test_unconfirmed_creation_cannot_replace_existing_utf8_json(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'new.json'; data={'name':'アスタリス'}
            write_new(path,data); self.assertEqual(json.loads(path.read_text(encoding='utf-8')),data)
            original=path.read_bytes()
            with self.assertRaises(FileExistsError):write_new(path,{'overwrite':True})
            self.assertEqual(path.read_bytes(),original); self.assertEqual(len(list(path.parent.iterdir())),1)
    def test_fixture_read_never_changes_source_and_old_image_default(self):
        source=Path(__file__).parent/'test_fixtures/campaign-a51a773-battle.json'; original=source.read_bytes()
        result=run({'action':'read','path':str(source),'allowed':[]})
        self.assertEqual(result['format'],'5525-native-campaign')
        self.assertEqual(result['nativePortraits'],{'version':1,'characters':{}})
        self.assertEqual(source.read_bytes(),original)
    def test_custom_portrait_embedded_and_hash_validation(self):
        source=Path(__file__).parent/'assets/knight.png'
        result=run({'action':'portrait','path':str(source)})
        meta={'version':1,'characters':{'guard':result}}
        self.assertEqual(prepare_portraits(meta,['guard']),meta)
        with self.assertRaises(ValueError):prepare_portraits(meta,['porter'])
        result['sha256']='0'*64
        with self.assertRaises(ValueError):prepare_portraits(meta,['guard'])
    @unittest.skipUnless(os.name == 'nt', 'Windows no-replace rename')
    def test_windows_does_not_require_hardlinks(self):
        with tempfile.TemporaryDirectory() as folder, patch('godot_files.os.link',side_effect=OSError(errno.ENOTSUP,'hardlinks unavailable')):
            path=Path(folder)/'new.json'
            write_new(path,{'value':1})
            self.assertEqual(json.loads(path.read_text()),{'value':1})

    def test_permission_and_disk_failure_leave_no_output_or_temporary(self):
        for fault in [PermissionError(errno.EACCES,'denied'),OSError(errno.ENOSPC,'full')]:
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as folder:
                path=Path(folder)/'new.json'
                target='godot_files.publish_new' if isinstance(fault,PermissionError) else 'godot_files.os.fsync'
                with patch(target,side_effect=fault), self.assertRaises(OSError):
                    write_new(path,{'value':1},'a'*32)
                self.assertEqual(list(Path(folder).iterdir()),[])

    def test_two_simultaneous_creators_publish_exactly_one_complete_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'race.json'; barrier=threading.Barrier(2)
            real=godot_files.publish_new
            def publish(temp,destination):
                barrier.wait(timeout=5); real(temp,destination)
            def writer(value):
                try:write_new(path,{'value':value},str(value)*32);return True
                except FileExistsError:return False
            with patch('godot_files.publish_new',side_effect=publish), ThreadPoolExecutor(2) as pool:
                result=list(pool.map(writer,[1,2]))
            self.assertEqual(sorted(result),[False,True])
            self.assertIn(json.loads(path.read_text())['value'],[1,2])
            self.assertEqual(list(Path(folder).iterdir()),[path])

    def test_recovery_reconciles_publication_and_only_cleans_owned_temporary(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'new.json'; data={'name':'アスタリス'}; token='a'*32
            other=Path(folder)/'keep.tmp'
            other.write_text('unrelated')
            temp=godot_files.operation_temp(path,token);temp.write_text('incomplete')
            result=godot_files.recover_write(path,data,token)
            self.assertEqual(result['outcome'],'not_saved');self.assertFalse(temp.exists());self.assertTrue(other.exists())
            write_new(path,data,token)
            self.assertEqual(godot_files.recover_write(path,data,token)['outcome'],'saved')
            original=path.read_bytes()
            self.assertEqual(godot_files.recover_write(path,{'different':1},token)['outcome'],'not_saved')
            self.assertEqual(path.read_bytes(),original)

    def test_operation_collision_and_invalid_token_never_remove_existing_temp(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'new.json';temp=godot_files.operation_temp(path,'a'*32);temp.write_text('other')
            with self.assertRaises(FileExistsError):write_new(path,{},'a'*32)
            self.assertEqual(temp.read_text(),'other')
            with self.assertRaises(ValueError):godot_files.recover_write(path,{},'../bad')
            self.assertTrue(temp.exists())

    def test_confirmed_replace_is_atomic_and_keeps_utf8(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save.json';write_new(path,{'old':1})
            original=path.read_bytes();fingerprint=godot_files.write_target(path)['sha256']
            real=os.replace
            def replace(temp,destination):
                self.assertEqual(path.read_bytes(),original)
                self.assertEqual(json.loads(Path(temp).read_text(encoding='utf-8')),{'new':'アスタリス'})
                real(temp,destination)
            with patch('godot_files.os.replace',side_effect=replace):
                result=run({'action':'write','path':str(path),'data':{'new':'アスタリス'},'overwrite':True,'expected_sha256':fingerprint})
            self.assertEqual(result['outcome'],'saved')
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')),{'new':'アスタリス'})
            self.assertEqual(list(path.parent.iterdir()),[path])

    def test_confirmation_is_required_and_stale_confirmation_preserves_newer_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save.json';write_new(path,{'old':1})
            original=path.read_bytes();fingerprint=godot_files.write_target(path)['sha256']
            with self.assertRaises(ValueError):godot_files.write_save(path,{},overwrite=True)
            self.assertEqual(path.read_bytes(),original)
            path.write_text('{"external":2}',encoding='utf-8');newer=path.read_bytes()
            with self.assertRaises(ValueError):godot_files.write_save(path,{},overwrite=True,expected_sha256=fingerprint)
            self.assertEqual(path.read_bytes(),newer)
            self.assertEqual(list(path.parent.iterdir()),[path])

    def test_overwrite_permission_disk_and_replace_failures_preserve_original(self):
        for target,fault in [('godot_files.os.fsync',OSError(errno.ENOSPC,'full')),
                             ('godot_files.os.replace',PermissionError(errno.EACCES,'denied')),
                             ('godot_files.os.replace',OSError(errno.EIO,'replace failed'))]:
            with self.subTest(target=target,fault=fault),tempfile.TemporaryDirectory() as folder:
                path=Path(folder)/'save.json';write_new(path,{'old':1});original=path.read_bytes()
                fingerprint=godot_files.write_target(path)['sha256']
                with patch(target,side_effect=fault),self.assertRaises(OSError):
                    godot_files.write_save(path,{'new':2},'b'*32,True,fingerprint)
                self.assertEqual(path.read_bytes(),original)
                self.assertEqual(list(path.parent.iterdir()),[path])

    def test_overwrite_recovery_distinguishes_old_and_published_contents(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save.json';write_new(path,{'old':1});original=path.read_bytes()
            data={'new':2};token='b'*32;temp=godot_files.operation_temp(path,token);temp.write_text('partial')
            self.assertEqual(godot_files.recover_write(path,data,token)['outcome'],'not_saved')
            self.assertEqual(path.read_bytes(),original);self.assertFalse(temp.exists())
            godot_files.write_save(path,data,token,True,godot_files.write_target(path)['sha256'])
            self.assertEqual(godot_files.recover_write(path,data,token)['outcome'],'saved')
            self.assertEqual(json.loads(path.read_text()),data)

    def test_target_probe_is_readonly_and_returns_real_parent_pin(self):
        with tempfile.TemporaryDirectory() as folder:
            missing=Path(folder)/'not-created'/'save.json'
            result=godot_files.write_target(missing)
            self.assertFalse(result['exists']);self.assertFalse(missing.parent.exists())
            self.assertEqual(result['resolved_target'],str(missing.parent.resolve()/missing.name))

    def test_publication_uses_resolved_siblings_and_logical_receipt(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder);logical=base/'logical';physical=base/'physical'
            logical.mkdir();physical.mkdir();path=logical/'save.json';real_path=physical/path.name
            resolve=Path.resolve
            def redirected(p,*args,**kwargs):
                return physical if p==logical else resolve(p,*args,**kwargs)
            with patch.object(Path,'resolve',redirected):
                target=godot_files.write_target(path)
                self.assertEqual(target['resolved_target'],str(real_path))
                result=run({'action':'write','path':str(path),'data':{'first':1},'operation':'a'*32,'resolved_target':target['resolved_target']})
                self.assertEqual(result['path'],str(path));self.assertFalse(path.exists());self.assertTrue(real_path.exists())
                target=godot_files.write_target(path);replace=os.replace
                def publish(temp,destination):
                    self.assertEqual(Path(temp).parent,physical);self.assertEqual(destination,real_path)
                    replace(temp,destination)
                with patch('godot_files.os.replace',side_effect=publish):
                    run({'action':'write','path':str(path),'data':{'next':'保存'},'operation':'b'*32,'overwrite':True,'expected_sha256':target['sha256'],'resolved_target':target['resolved_target']})
                self.assertEqual(json.loads(real_path.read_text(encoding='utf-8')),{'next':'保存'})
                self.assertEqual(list(physical.iterdir()),[real_path]);self.assertEqual(list(logical.iterdir()),[])

    def test_changed_real_parent_rejects_even_identical_old_contents(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder);first=base/'first';second=base/'second';first.mkdir();second.mkdir()
            path=first/'save.json';other=second/'save.json'
            write_new(path,{'old':1});write_new(other,{'old':1});old=other.read_bytes();target=godot_files.write_target(path)
            with self.assertRaisesRegex(ValueError,'実体'):
                godot_files.write_save(other,{'new':2},'c'*32,True,target['sha256'],target['resolved_target'])
            self.assertEqual(path.read_bytes(),old);self.assertEqual(other.read_bytes(),old)
            self.assertEqual(list(second.iterdir()),[other])

    def test_recovery_uses_original_pin_after_logical_parent_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder);physical=base/'first';logical=base/'second';physical.mkdir();logical.mkdir()
            pinned=physical/'save.json';display=logical/'save.json';data={'published':'正しい保存'};token='d'*32
            write_new(pinned,data);display.write_text('{"unrelated":1}',encoding='utf-8');old=display.read_bytes()
            own=godot_files.operation_temp(pinned,token);own.write_text('partial')
            keep=godot_files.operation_temp(display,token);keep.write_text('unrelated')
            result=run({'action':'recover_write','path':str(display),'data':data,'operation':token,'resolved_target':str(pinned)})
            self.assertEqual(result['outcome'],'saved');self.assertEqual(result['path'],str(display))
            self.assertFalse(own.exists());self.assertEqual(keep.read_text(),'unrelated');self.assertEqual(display.read_bytes(),old)

    def test_invalid_real_target_pin_never_writes_or_cleans_other_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save.json'
            for bad in ['relative/save.json',17]:
                with self.subTest(pin=bad),self.assertRaises(ValueError):
                    godot_files.write_save(path,{},resolved_target=bad)
            other=Path(folder)/'other.json';temp=godot_files.operation_temp(other,'a'*32);temp.write_text('keep')
            with self.assertRaises(ValueError):godot_files.recover_write(path,{},'a'*32,str(other))
            self.assertEqual(temp.read_text(),'keep');self.assertFalse(path.exists())


if __name__=='__main__':unittest.main()
