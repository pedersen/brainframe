import cmd
import os
import sys

try:
    import readline
except:
    readline = None

from selenium import webdriver

from brainframe.config import Config
from brainframe.articles import get_article, get_product


class BrainFrameShell(cmd.Cmd):
    intro: str = 'Welcome to the BrainFrame shell.   Type help or ? to list commands.\n'
    prompt: str = '(brainframe) '
    cfg: Config = None
    driver: webdriver.Firefox = None

    def __init__(self, cfg: Config = None):
        cmd.Cmd.__init__(self)
        self.cfg = Config() if not cfg else cfg
        self.driver = webdriver.Firefox(firefox_binary=self.cfg.firefox_binary)

    def __del__(self):
        if self.driver:
            self.driver.close()

    def do_reload(self, arg):
        """Save history, and restart brainframe to enable new functionality or fix bugs:  RELOAD"""
        self.postloop()
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def do_quit(self, arg):
        """Stop recording, close the turtle window, and exit:  QUIT"""
        print('Thank you for using BrainFrame')
        return True

    def do_getarticle(self, arg):
        """Retrieve an article, convert to markdown, and save it to the zettelkasten: GETARTICLE URL"""
        url = arg.split()[0]
        get_article(url, self.driver)

    def do_getproduct(self, arg):
        """Retrieve product name from website, and store that + link in products file: GETPRODUCT URL"""
        url = arg.split()[0]
        get_product(url, self.driver)

    def preloop(self) -> None:
        self.cfg.load_cfg()
        self.cfg.load_histfile()

    def postloop(self) -> None:
        self.cfg.save_cfg()
        self.cfg.save_histfile()


def repl():
    BrainFrameShell().cmdloop()
