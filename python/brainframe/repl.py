import cmd
import os
import sys

try:
    import readline
except:
    readline = None


class BrainFrameShell(cmd.Cmd):
    intro = 'Welcome to the BrainFrame shell.   Type help or ? to list commands.\n'
    prompt = '(brainframe) '
    rcfile = os.path.expanduser('~/.brainframerc')
    histfile = os.path.expanduser('~/.brainframe_history')
    histfile_size = 1000

    def do_reload(self, arg):
        """Save history, and restart brainframe to enable new functionality or fix bugs:  RELOAD"""
        self.postloop()
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def do_quit(self, arg):
        """Stop recording, close the turtle window, and exit:  QUIT"""
        print('Thank you for using BrainFrame')
        return True

    def preloop(self) -> None:
        if readline and os.path.exists(self.histfile):
            readline.read_history_file(self.histfile)

    def postloop(self) -> None:
        if readline:
            readline.set_history_length(self.histfile_size)
            readline.write_history_file(self.histfile)


def repl():
    BrainFrameShell().cmdloop()
