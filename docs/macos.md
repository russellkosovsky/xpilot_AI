# Running on macOS

The binaries checked into this repository are Linux x86-64 builds. On a Mac,
`mac/build.sh` builds native versions (arm64 or x86-64) of the XPilot 4.5.5
programs and the Xpilot-AI libraries from source.

## Requirements

- **Xcode Command Line Tools:** `xcode-select --install`
- **X11 headers and libraries:** `brew install libx11 libxext`
- **XQuartz, the X server that displays the game:** `brew install --cask xquartz`.
  The installer needs your password, so run it in a normal terminal, then log
  out and back in once. Until you do, start it with `open -a XQuartz`.
- **Python 3 (optional):** for the Python library. By default the build uses
  whatever `python3` is on your `PATH`.
- **A JDK (optional):** for the Java library. The build finds it through
  `JAVA_HOME` or `/usr/libexec/java_home`.

## Building

```sh
mac/build.sh                      # uses python3
PYTHON=python3.14 mac/build.sh    # builds the Python module for a different Python
```

The script:

1. Downloads the XPilot 4.5.5 source from the Xpilot-AI repository into
   `mac/build/` and checks its SHA-256.
2. Builds the server with the Xpilot-AI server files (`source/cmdlineAI.c`,
   `source/playerAI.c`), the stock client, `xp-mapedit` and `xp-replay`.
3. Builds the AI libraries from `source/` and `library/`:
   - `libcAI.dylib` with `cAI.h`
   - `libpyAI.cpython-XY-darwin.so`, for the Python that ran the build
   - `libjavaAI.dylib` with `javaAI.java` and `javaAI.class`
4. Installs the server data (defaults, robots, the stock maps plus this repo's
   `maps/`) into `mac/lib/xpilot`. The server finds it there because the build
   compiles that path into it.
5. Copies the Python and Java libraries into every folder under `bots/` that
   holds a bot, so each bot runs from its own folder.

Everything it creates (`mac/bin`, `mac/build`, `mac/lib` and the copied
libraries) is ignored by git. Rerun the script after changing anything in
`source/` or `library/`, or after adding a bot folder.

### How the Mac and Linux libraries share a folder

Several bot folders also contain the Linux `libpyAI.so` and `libjavaAI.so`.
They don't conflict with the Mac builds:

- **Python:** on macOS, Python looks for `libpyAI.cpython-39-darwin.so` (for
  Python 3.9) before plain `libpyAI.so`. Linux Python never looks for the
  `darwin` name.
- **Java:** `System.loadLibrary("javaAI")` loads `libjavaAI.dylib` on macOS and
  `libjavaAI.so` on Linux.

## Running

```sh
mac/server.sh                       # server on simple.xp
mac/server.sh pit.xp -robots 2      # another map, with two robot opponents
mac/bin/xpilot -join localhost      # human player
cd bots && python3 Spinner.py       # Python bot
cd bots && java -Djava.library.path=. Spinner          # Java bot
cd bots/geneticAI/xpilotGA && javac *.java && java -Djava.library.path=. GeneticAlgorithm 20 10
```

A C bot links against the library in `mac/bin`:

```sh
clang -I mac/bin MyBot.c -L mac/bin -lcAI -Wl,-rpath,"$PWD/mac/bin" -o MyBot
./MyBot -name MyBot -join localhost
```

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Can't open display ':0.0'` | XQuartz isn't running. Run `open -a XQuartz`, or log out and back in after installing it. Bots need it too, even with `ai.headlessMode()`. |
| `ImportError: dlopen(.../libpyAI.so ...) ... slice is not valid mach-o file` | Python found only the Linux `libpyAI.so`. Either the Mac module is missing (run `mac/build.sh`) or it was built for a different Python (see the next row). |
| `ModuleNotFoundError: No module named 'libpyAI'` | There's no module for this Python in the bot's folder. The build names the module after the Python version (`cpython-39` for 3.9), so run the bot with the Python you built for, or rebuild with `PYTHON=<your python> mac/build.sh`. |
| `ModuleNotFoundError: No module named 'numpy'` | Only `bots/perceptron/nn.py` uses numpy. Run `python3 -m pip install --user numpy`. |
| `UnsatisfiedLinkError: no javaAI in java.library.path` | Pass `-Djava.library.path=.` from a folder that has `libjavaAI.dylib`, or point it at `mac/bin`. |
| The bot opens a server list instead of playing | Its arguments lack `-join localhost`. |
| A Java bot writes an `hs_err_pid*.log` when you press Ctrl-C | The client's signal handler runs on a JVM thread when the process is killed. It's harmless; bots that call `quitAI()` exit cleanly. |
| A second game in the same process crashes | The client can only start once per process. Start a new process for each game. |
| `xpilots` startup line "Locating Internet Meta server" | The server is reporting itself publicly. Use `mac/server.sh`, or pass `+reportMeta`. |
