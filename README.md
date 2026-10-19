# xp

## Running on macOS (native, Apple Silicon or Intel)

The binaries at the top level (`xpilot`, `xpilots`, `bots/libpyAI.so`, ...) are
Linux x86-64 builds and do not run on a Mac. `mac/build.sh` builds native
versions from the XPilot 4.5.5 source plus this repo's `source/` and `library/`.

One-time setup:

```sh
xcode-select --install            # if the Command Line Tools are missing
brew install libx11 libxext       # X11 headers and libraries
brew install --cask xquartz       # X server (asks for your password); log out and back in afterwards
mac/build.sh                      # builds into mac/bin, copies the AI libraries into bots/
```

Play:

```sh
mac/server.sh                     # server on simple.xp; or: mac/server.sh pit.xp -switchBase 0.5
mac/bin/xpilot -join localhost    # in a second terminal: the regular client
cd bots && python3 Spinner.py     # in a third terminal: a Python bot
```

Notes:

- The Python module is built for the `python3` used by `mac/build.sh`. To use a
  different one, run `PYTHON=python3.14 mac/build.sh`.
- Java bots: `cd bots && java -Djava.library.path=. Spinner`.
- Bots need XQuartz running even with `ai.headlessMode()`, because the client
  still opens the X display.
- Server data (defaults, robots, maps) lives in `mac/lib/xpilot`; `mac/build.sh`
  copies the repo's `maps/` there.
