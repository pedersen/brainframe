import cmd
import os
import sys

try:
    import readline
except:
    readline = None

from brainframe.config import Config


class BrainFrameShell(cmd.Cmd):
    intro: str = 'Welcome to the BrainFrame shell.   Type help or ? to list commands.\n'
    prompt: str = '(brainframe) '
    cfg: Config = None

    def __init__(self, cfg: Config = None):
        cmd.Cmd.__init__(self)
        self.cfg = Config() if not cfg else cfg

    def do_reload(self, arg):
        """Save history, and restart brainframe to enable new functionality or fix bugs:  RELOAD"""
        self.postloop()
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def do_quit(self, arg):
        """Stop recording, close the turtle window, and exit:  QUIT"""
        print('Thank you for using BrainFrame')
        return True

    def preloop(self) -> None:
        self.cfg.load_histfile()

    def postloop(self) -> None:
        self.cfg.save_histfile()


def repl():
    BrainFrameShell().cmdloop()
