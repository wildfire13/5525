import ctypes as C
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock
import wave
from wave_audio import WaveOutput, WaveHeader


class WaveAudioTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory();self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name)/'test.wav'
        with wave.open(str(self.path),'wb') as w:
            w.setparams((2,3,48000,480,'NONE',''));w.writeframes(b'\1\2\3'*960)
        self.dll = Mock()
        for name in ['waveOutOpen','waveOutPrepareHeader','waveOutWrite','waveOutReset','waveOutUnprepareHeader','waveOutClose']:
            getattr(self.dll,name).return_value=0
        def opened(handle,*args):C.cast(handle,C.POINTER(C.c_void_p))[0]=C.c_void_p(123);return 0
        self.dll.waveOutOpen.side_effect=opened
        self.backend=WaveOutput(dll=self.dll);self.addCleanup(self.backend.stop)

    def test_single_submission_device_loop_and_owned_cleanup(self):
        self.backend.start(self.path)
        self.assertEqual(self.backend.header.flags & 12,12)
        self.assertEqual(self.backend.header.loops,0xffffffff)
        self.assertEqual(self.backend.header.length,2880)
        self.assertEqual(C.string_at(self.backend.header.data,2880),b'\1\2\3'*960)
        for _ in range(30):self.assertTrue(self.backend.playing())
        self.dll.waveOutWrite.assert_called_once()
        self.backend.stop();self.backend.stop()
        self.dll.waveOutReset.assert_called_once();self.dll.waveOutClose.assert_called_once()
        self.assertIsNone(self.backend.buffer)

    def test_write_failure_releases_prepared_buffer(self):
        self.dll.waveOutWrite.return_value=1
        with self.assertRaises(OSError):self.backend.start(self.path)
        self.assertFalse(self.backend.opened)
        self.dll.waveOutUnprepareHeader.assert_called_once()

    def test_one_shot_does_not_loop_and_done_is_detected(self):
        self.backend.loop=False;self.backend.start(self.path)
        self.assertEqual(self.backend.header.flags & 12,0)
        self.backend.header.flags|=1
        self.assertFalse(self.backend.playing())

    def test_prepare_failure_closes_without_unprepare(self):
        self.dll.waveOutPrepareHeader.return_value=1
        with self.assertRaises(OSError):self.backend.start(self.path)
        self.dll.waveOutUnprepareHeader.assert_not_called()
        self.dll.waveOutClose.assert_called_once()

    def test_hardware_loop_player_does_not_schedule_restarts(self):
        from music import MusicPlayer
        root=Mock();catalog=Mock(tracks={'track':self.path})
        player=MusicPlayer(root,catalog,self.backend)
        self.addCleanup(player.close);player.select('track')
        root.after.assert_not_called()
        self.dll.waveOutWrite.assert_called_once()


if __name__=='__main__':unittest.main()
