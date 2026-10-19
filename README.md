# XPilot-AI bots

Bots and machine-learning experiments for [XPilot](https://man.cx/xpilot), a 2D
multiplayer space-combat game, written for COM407 Computational Intelligence
(2023). They use [Xpilot-AI](https://gitlab.com/xpilot-ai/xpilot-ai), a
modified XPilot 4.5.5 client that calls your code once per game frame and lets
it read the game state and press keys from Python, Java or C.

The bots range from hand-written rules to fuzzy logic, genetic algorithms and
neural networks. See [`bots/README.md`](bots/README.md) for the full list.

## Repository layout

| Path | Contents |
|---|---|
| [`bots/`](bots/README.md) | The bots and learning experiments, one folder per approach |
| `maps/` | Server maps (`.xp`), including the course maps such as `simple.xp` |
| `source/` | Xpilot-AI's modified XPilot 4.5.5 client and server sources (`clientAI.c`, `cmdlineAI.c`, ...) |
| `library/` | The AI libraries: `python/pyAI.c` (`libpyAI`), `java/javaAI.java` with its native side in `c/javaAI.c`, and `c/cAI.c` with `cAI.h` |
| `xpilot`, `xpilots`, `xp-mapedit`, `xp-replay` | Prebuilt Linux x86-64 client, server, map editor and replay viewer |
| [`mac/`](docs/macos.md) | Native macOS build: `build.sh` and `server.sh` |
| `docs/` | [AI library reference](docs/api.md) and [macOS build notes](docs/macos.md) |

## Setup

### macOS (Apple Silicon or Intel)

The top-level binaries are Linux builds, so on a Mac you build native ones:

```sh
xcode-select --install            # if the Command Line Tools are missing
brew install libx11 libxext       # X11 headers and libraries
brew install --cask xquartz       # X server; asks for your password, then log out and back in
mac/build.sh                      # builds into mac/bin and copies the AI libraries into each bot folder
```

Then use `mac/server.sh` and `mac/bin/xpilot` in the commands below.
[`docs/macos.md`](docs/macos.md) explains what the build does and how to fix
common problems.

### Linux (x86-64)

The prebuilt binaries at the top level and the libraries in `bots/`
(`libpyAI.so`, `libjavaAI.so`) were built on Ubuntu and need `libX11`. Run the
server as `./xpilots -map maps/simple.xp +reportMeta` and the client as
`./xpilot`. To rebuild them, use the install script in the upstream
[xpilot-ai repository](https://gitlab.com/xpilot-ai/xpilot-ai)
(`scripts/xpilot-ai-1.1.1604-linux.sh`).

## Playing a game

A game needs a server, then any mix of human players and bots. Open a terminal
for each:

```sh
mac/server.sh                         # 1. server on simple.xp
mac/bin/xpilot -join localhost        # 2. join as a human player
cd bots && python3 Spinner.py         # 3. add a bot
```

The default keys are `a`/`s` to turn, `Shift` to thrust, `Return` to fire and
`Space` for the shield.

### Server options

`mac/server.sh [map] [options]` starts `xpilots` with `+reportMeta` and
`-noQuit`. You can add any `xpilots` option after the map name:

| Option | Default | Effect |
|---|---|---|
| `-map NAME` | `simple.xp` in `mac/server.sh` | Map file name or path |
| `-robots N` | 4, but 0 on `simple.xp` | Maximum number of built-in robot players. Robots join once a player is connected, which is a quick way to give a bot an opponent |
| `-FPS N` | 14 | Game frames per second, which is also how often `AI_loop` runs |
| `-switchBase P` | 0.0 | Probability that a ship gets a new home base after each death (Xpilot-AI addition) |
| `+reportMeta` | on | Don't list this server on the public XPilot meta server |
| `-noQuit` | off | Keep the server running when the last player leaves |
| `-port N` | 15345 | Port that clients connect to |

Boolean options use `-name` to turn them on and `+name` to turn them off.
`-reportMeta no` turns reporting *on*. `xpilots -help` lists every option.

`simple.xp` is 32×32 blocks (a block is 35 pixels). Bots often spend a long
time on it without coming within screen range of each other, so try a smaller
map when you need fights quickly.

## Writing a bot

A bot defines `AI_loop()`, which the client calls once per frame, and starts
the client with `ai.start`:

```python
import libpyAI as ai

def AI_loop():
    # Keys stay pressed until released, so release them first.
    ai.thrust(0)
    ai.turnLeft(0)
    ai.turnRight(0)

    if ai.wallFeeler(500, int(ai.selfHeadingDeg())) < 200:
        ai.turnLeft(1)        # wall ahead: turn away
    else:
        ai.thrust(1)
    ai.fireShot()

ai.start(AI_loop, ["-name", "MyBot", "-join", "localhost"])
```

Run it from a folder that has the AI library. `bots/` and every bot folder
under it have one after `mac/build.sh`. Java bots extend `javaAI` and override
`AI_loop()`. C bots define `AI_loop()` and call `start(argc, argv)`.
[`docs/api.md`](docs/api.md) has examples in all three languages and lists
every function.

Things that catch people out:

- **Joining:** without `-join localhost`, the client opens its server picker
  window and waits for you to choose a server.
- **One game per process:** the client can only start once per process. After
  `quitAI()`, start a new process for the next game. The genetic algorithm in
  `bots/geneticAI/xpilotGA` does this for each chromosome.
- **Headless still needs an X server:** `ai.headlessMode()` hides the game
  window, but the client still connects to the X server, so XQuartz (or X11
  on Linux) must be running.
- **Angles** are in degrees, counterclockwise from 0° = east. `turnLeft`
  increases your heading.
- **Missing prints:** Python buffers `print` output when it's redirected to a
  file. Use `print(..., flush=True)` or `python3 -u` to see it while the bot
  runs.

## Further reading

- [Xpilot-AI documentation](https://connaall.github.io/xpilot-ai-documentation/):
  installation, examples and the upstream function library
- [Xpilot-AI source](https://gitlab.com/xpilot-ai/xpilot-ai)
- XPilot manual pages: [client](https://man.cx/xpilot) and [server](https://man.cx/xpilots)
- [xpilot.io](http://xpilot.io): XPilot in the browser
