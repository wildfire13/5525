"""Bounded, process-local startup workaround for the tested Codex Windows runtime.

Ordinary Python installations and user-supplied Tcl/Tk settings are left alone.
The initialization order below was observed to work on Python 3.12.14 x64 with
Tcl/Tk 8.6.12. It does not establish the underlying cause of the startup failure.
"""
import ctypes
import os
from pathlib import Path
import sys

_prepared = False


def prepare_tk():
    global _prepared
    if _prepared or sys.platform != 'win32' or ctypes.sizeof(ctypes.c_void_p) != 8:
        return False
    runtime = Path(sys.executable).resolve().parent
    # Deliberately restrict this workaround to the observed existing layout.
    if runtime.parent.name != 'dependencies' or runtime.parent.parent.name != 'codex-primary-runtime':
        return False
    tcl = runtime / 'tcl' / 'tcl8.6'
    tk = runtime / 'tcl' / 'tk8.6'
    dll = runtime / 'DLLs' / 'tcl86t.dll'
    if not all(p.is_file() for p in (dll, tcl / 'init.tcl', tk / 'tk.tcl')):
        return False
    # Explicit settings belong to the caller; never substitute different paths.
    for key, expected in [('TCL_LIBRARY', tcl), ('TK_LIBRARY', tk)]:
        if key in os.environ and Path(os.environ[key]).resolve() != expected.resolve():
            return False
    if sys.version_info[:3] != (3, 12, 14):
        return False
    for script in (tcl / 'init.tcl', tk / 'tk.tcl'):
        if '8.6.12' not in script.read_text(encoding='utf-8'):
            return False
    library = ctypes.CDLL(str(dll))
    library.Tcl_GetVersion.argtypes = [ctypes.POINTER(ctypes.c_int)] * 4
    library.Tcl_GetVersion.restype = None
    parts = [ctypes.c_int() for _ in range(4)]
    library.Tcl_GetVersion(*(ctypes.byref(p) for p in parts))
    if tuple(p.value for p in parts[:3]) != (8, 6, 12):
        return False
    library.Tcl_FindExecutable.argtypes = [ctypes.c_char_p]
    library.Tcl_FindExecutable.restype = None
    library.Tcl_CreateInterp.argtypes = []
    library.Tcl_CreateInterp.restype = ctypes.c_void_p
    library.Tcl_Eval.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    library.Tcl_Eval.restype = ctypes.c_int
    library.Tcl_GetStringResult.argtypes = [ctypes.c_void_p]
    library.Tcl_GetStringResult.restype = ctypes.c_char_p
    library.Tcl_DeleteInterp.argtypes = [ctypes.c_void_p]
    library.Tcl_DeleteInterp.restype = None
    previous = {key: os.environ.get(key) for key in ('TCL_LIBRARY', 'TK_LIBRARY')}
    try:
        os.environ.setdefault('TCL_LIBRARY', tcl.as_posix())
        os.environ.setdefault('TK_LIBRARY', tk.as_posix())
        library.Tcl_FindExecutable(str(sys.executable).encode('utf-8'))
        interp = library.Tcl_CreateInterp()
        if not interp:
            raise RuntimeError('Tcl_CreateInterp returned a null interpreter')
        try:
            if library.Tcl_Eval(interp, b'pwd') != 0:
                detail = library.Tcl_GetStringResult(interp) or b'unknown Tcl error'
                raise RuntimeError('Tcl startup: ' + detail.decode('utf-8', errors='replace'))
        finally:
            library.Tcl_DeleteInterp(interp)
    except Exception:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        raise
    _prepared = True
    return True


if __name__ == '__main__':
    prepare_tk()
    import tkinter as tk
    root = None
    try:
        root = tk.Tk()
        root.withdraw()
    finally:
        if root is not None:
            root.destroy()
