import configparser
import os

try:
    import readline
except:
    readline = None

from dataclasses import dataclass, fields

rcfilename: str = os.environ.get("BRAINFRAMERC", os.path.expanduser('~/.brainframerc'))
zettelbase: str = os.environ.get("BRAINFRAMEZETTEL", os.path.expanduser('~/zettel'))


@dataclass
class Config:
    histfile: str = os.path.expanduser('~/.brainframe_history')
    histfile_size: int = 1000
    zetteldir: str = os.environ.get("BRAINFRAMEZETTEL", os.path.expanduser('~/zettel'))
    articledir: str = os.path.join(zetteldir, 'articles-to-read')
    products_md: str = os.path.join(zetteldir, 'products.md')

    def load_cfg(self, filename: str = None):
        if not filename:
            filename = rcfilename
        if not os.path.exists(filename):
            return
        config = configparser.ConfigParser()
        config.read(filename)
        if 'DEFAULTS' not in config:
            return

        defaults = config['DEFAULTS']
        for key in fields(self):
            setattr(self, key.name, key.type(defaults.get(key.name, getattr(self, key.name))))

    def save_cfg(self, filename: str = None):
        if not filename:
            filename = rcfilename
        config = configparser.ConfigParser()
        config['DEFAULTS'] = {}

        defaults = config['DEFAULTS']
        for key in fields(self):
            defaults[key.name] = str(getattr(self, key.name))
        with open(filename, 'w') as configfp:
            config.write(configfp)

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
