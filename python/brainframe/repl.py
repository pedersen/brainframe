import cmd
import os

import readline


class BrainFrameShell(cmd.Cmd):
    intro = 'Welcome to the BrainFrame shell.   Type help or ? to list commands.\n'
    prompt = '(brainframe) '
    rcfile = os.path.expanduser('~/.brainframerc')
    histfile = os.path.expanduser('~/.brainframe_history')
    histfile_size = 1000

    def do_args(self, arg):
        """Show the current arguments: ARGS"""
        print(", ".join(arg.split()))

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
