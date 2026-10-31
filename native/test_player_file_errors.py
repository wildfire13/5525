import errno
import json
import unittest
from godot_files import player_error

class PlayerFileErrors(unittest.TestCase):
    def test_os_errors_exclude_paths_and_internal_details(self):
        for error in [FileNotFoundError(errno.ENOENT,'private-name','/private/person/save.json'),PermissionError(errno.EACCES,'private-name','C:/Users/person/save.json'),OSError(errno.ENOSPC,'private-name','/private/person/save.json')]:
            message=player_error(error)
            self.assertNotIn('private',message)
            self.assertNotIn('person',message)
            self.assertNotIn('Errno',message)
            self.assertTrue('ください' in message)
    def test_invalid_content_and_expected_validation(self):
        for error in [json.JSONDecodeError('private-text','private-content',2),KeyError('private-key'),ValueError('private data')]:
            self.assertNotIn('private',player_error(error))
        message='確認後に保存先の内容が変わりました。保存先を選び直してください。'
        self.assertEqual(player_error(ValueError(message)),message)
