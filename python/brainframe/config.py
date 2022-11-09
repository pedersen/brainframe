import os.path

try:
    import readline
except:
    readline = None

from dataclasses import dataclass


@dataclass
class Config:
    rcfilename: str = os.path.expanduser('~/.brainframerc')
    histfile: str = os.path.expanduser('~/.brainframe_history')
    histfile_size: int = 1000

    def load_cfg(self, rcfilename: str = None):
        if not rcfilename:
            rcfilename = self.rcfilename

    def load_histfile(self, histfile: str = None):
        if not histfile:
            histfile = self.histfile

        if readline and os.path.exists(histfile):
            readline.read_history_file(histfile)

    def save_histfile(self, histfile: str = None, histfile_size: int = None):
        if not histfile:
            histfile = self.histfile

        if not histfile_size:
            histfile_size = self.histfile_size

        if readline:
            readline.set_history_length(histfile_size)
            readline.write_history_file(histfile)
