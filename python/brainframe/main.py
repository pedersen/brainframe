from brainframe.repl import repl

try:
    import readline
except:
    readline = None


def main():
    repl()


if __name__ == '__main__':
    repl()
