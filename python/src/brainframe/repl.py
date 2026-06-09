import atexit
import cmd
import os
import sys

try:
    import readline
except:
    readline = None

from selenium import webdriver

from brainframe.config import Config
from brainframe.articles import get_article, get_product, gitmark
from brainframe.journey_cloud import import_journey


class BrainFrameShell(cmd.Cmd):
    intro: str = 'Welcome to the BrainFrame shell.   Type help or ? to list commands.\n'
    prompt: str = '(brainframe) '
    cfg: Config = None
    driver: webdriver.Firefox = None

    def close_browser(self):
        if self.driver:
            self.driver.close()
            self.driver = None

    def __init__(self, cfg: Config = None):
        cmd.Cmd.__init__(self)
        self.cfg = Config() if not cfg else cfg
        self.driver = webdriver.Firefox(firefox_binary=self.cfg.firefox_binary)
        atexit.register(self.close_browser)

    def do_reload(self, arg):
        """Save history, and restart brainframe to enable new functionality or fix bugs:  RELOAD"""
        self.postloop()
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def do_quit(self, arg):
        """Exits Brainframe. Also called via Control-D:  QUIT"""
        print('Thank you for using BrainFrame')
        return True

    def do_EOF(self, *args):
        """Exits Brainframe. Also called via Control-D: EOF"""
        self.do_quit(None)
        return True

    def do_aget(self, arg):
        """Retrieve an article, convert to markdown, and save it to the zettelkasten: PGET URL"""
        url = arg.split()[0]
        get_article(url, self.driver)

    def do_pget(self, arg):
        """Retrieve product name from website, and store that + link in products file: PGET URL"""
        url = arg.split()[0]
        get_product(url, self.driver)

    def do_gm(self, arg):
        """Retrieve basic info from Github, and store that info + link in gitmarks file: GM URL"""
        url = arg.split()[0]
        gitmark(url, self.driver)

    def do_import_journey_cloud(self, arg):
        """Import a journey.cloud zip export of data: IMPORT_JOURNEY_CLOUD ZIPFILENAME"""
        zipfilename = arg.split()[0]
        import_journey(zipfilename)

    def preloop(self) -> None:
        self.cfg.load_cfg()
        self.cfg.load_histfile()

    def postloop(self) -> None:
        self.cfg.save_cfg()
        self.cfg.save_histfile()
        self.close_browser()


def repl():
    BrainFrameShell().cmdloop()
