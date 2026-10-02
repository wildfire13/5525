"""Local save-write guarantees; does not operate a graphical desktop."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
from campaign_app import atomic_json_write

class CampaignFileTests(unittest.TestCase):
    def test_complete_unicode_json_replaces_existing_save(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save.json';path.write_text('previous',encoding='utf-8')
            atomic_json_write(path,{'place':'アスタリス','gold':180})
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')),{'place':'アスタリス','gold':180})
            self.assertEqual(list(Path(folder).iterdir()),[path])
    def test_replace_failure_keeps_previous_file_and_cleans_temp(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save.json';path.write_text('previous',encoding='utf-8')
            with mock.patch('campaign_app.os.replace',side_effect=OSError('test denied')):
                with self.assertRaises(OSError):atomic_json_write(path,{'gold':180})
            self.assertEqual(path.read_text(encoding='utf-8'),'previous')
            self.assertEqual(list(Path(folder).iterdir()),[path])
    def test_serialization_failure_keeps_previous_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'save.json';path.write_text('previous',encoding='utf-8')
            with self.assertRaises(TypeError):atomic_json_write(path,{'unsupported':object()})
            self.assertEqual(path.read_text(encoding='utf-8'),'previous')
            self.assertEqual(list(Path(folder).iterdir()),[path])

if __name__=='__main__':unittest.main()
