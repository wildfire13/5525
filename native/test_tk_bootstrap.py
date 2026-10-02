"""Mocked safety/control tests; real Windows Tk evidence is separate."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import tk_bootstrap as boot


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.runtime = Path(self.temp.name) / 'codex-primary-runtime/dependencies/python'
        for name in ('DLLs/tcl86t.dll', 'tcl/tcl8.6/init.tcl', 'tcl/tk8.6/tk.tcl'):
            path = self.runtime / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('8.6.12', encoding='utf-8')
        self.lib = Mock()
        def version(*parts):
            for p, n in zip(parts, [8, 6, 12, 2]):
                p._obj.value = n
        self.lib.Tcl_GetVersion.side_effect = version
        self.lib.Tcl_CreateInterp.return_value = 123
        self.lib.Tcl_Eval.return_value = 0
        self.lib.Tcl_GetStringResult.return_value = b'fixture error'
        for target, value in [('platform', 'win32'), ('version_info', (3, 12, 14)),
                              ('executable', str(self.runtime / 'python.exe'))]:
            p = patch.object(boot.sys, target, value);p.start();self.addCleanup(p.stop)
        p = patch.object(boot.ctypes, 'CDLL', return_value=self.lib)
        self.load = p.start();self.addCleanup(p.stop)
        p = patch.dict(os.environ, {}, clear=True);p.start();self.addCleanup(p.stop)
        p = patch.object(boot, '_prepared', False);p.start();self.addCleanup(p.stop)

    def test_success_and_idempotence(self):
        self.assertTrue(boot.prepare_tk())
        self.lib.Tcl_Eval.assert_called_once_with(123, b'pwd')
        self.lib.Tcl_DeleteInterp.assert_called_once_with(123)
        self.assertEqual(os.environ['TCL_LIBRARY'], (self.runtime/'tcl/tcl8.6').as_posix())
        self.assertFalse(boot.prepare_tk())
        self.load.assert_called_once()

    def test_other_platform_untouched(self):
        with patch.object(boot.sys, 'platform', 'linux'):
            self.assertFalse(boot.prepare_tk())
        self.load.assert_not_called()
        self.assertNotIn('TCL_LIBRARY', os.environ)

    def test_other_python_version_untouched(self):
        with patch.object(boot.sys, 'version_info', (3, 13, 0)):
            self.assertFalse(boot.prepare_tk())
        self.load.assert_not_called()

    def test_explicit_settings_preserved(self):
        os.environ['TCL_LIBRARY'] = str(self.runtime/'custom')
        self.assertFalse(boot.prepare_tk())
        self.load.assert_not_called()
        self.assertEqual(os.environ['TCL_LIBRARY'], str(self.runtime/'custom'))

    def test_dll_version_mismatch_untouched(self):
        def version(*parts):
            for p, n in zip(parts, [8, 6, 13, 2]):p._obj.value = n
        self.lib.Tcl_GetVersion.side_effect = version
        self.assertFalse(boot.prepare_tk())
        self.lib.Tcl_FindExecutable.assert_not_called()
        self.assertNotIn('TCL_LIBRARY', os.environ)

    def test_eval_failure_cleans_up(self):
        self.lib.Tcl_Eval.return_value = 1
        with self.assertRaisesRegex(RuntimeError, 'fixture error'):boot.prepare_tk()
        self.lib.Tcl_DeleteInterp.assert_called_once_with(123)
        self.assertNotIn('TCL_LIBRARY', os.environ)
        self.assertNotIn('TK_LIBRARY', os.environ)
        self.assertFalse(boot._prepared)

    def test_null_interpreter_cleans_environment(self):
        self.lib.Tcl_CreateInterp.return_value = None
        with self.assertRaisesRegex(RuntimeError, 'null interpreter'):boot.prepare_tk()
        self.lib.Tcl_DeleteInterp.assert_not_called()
        self.assertNotIn('TCL_LIBRARY', os.environ)
