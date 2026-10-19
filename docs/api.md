# AI library reference

The Xpilot-AI libraries let a program play XPilot. Each one wraps the same
modified XPilot client and exposes the same functions:

| Language | Library | Source |
|---|---|---|
| Python | `libpyAI` module (`import libpyAI as ai`) | `library/python/pyAI.c` |
| Java | `javaAI` class, extended by your bot | `library/java/javaAI.java`, native side in `library/c/javaAI.c` |
| C | `libcAI` with `cAI.h` | `library/c/cAI.c` |

The tables below use the Python names and types. Java and C use the same
function names and arguments, and Python alone has `switchLoop`.

## How a bot runs

1. Your program calls `start`, which connects to a server and then calls your
   `AI_loop` function once per game frame. The server's default is 14 frames
   per second; change it with the server's `-FPS` option.
2. In each frame, `AI_loop` reads the game state (`selfX`, `wallFeeler`,
   `enemyDistance`, ...) and presses or releases keys (`thrust`, `turnLeft`,
   `fireShot`, ...).
3. A key stays pressed until you release it. Most bots release everything at
   the top of `AI_loop` and then press what they need.
4. `quitAI()` ends the game and `start` returns. The client can only start once
   per process, so run each game in its own process.

`start` takes the regular `xpilot` client options:

| Option | Effect |
|---|---|
| `-name NAME` | Player name |
| `-join HOST` | Join the server on `HOST` straight away. Without it the client opens its server picker window |
| `-team N` | Team to join on a team map |
| `-port N` | Server port (default 15345) |

Call `headlessMode()` before `start` to run without a game window. The client
still connects to the X server, so XQuartz (or X11 on Linux) must be running.

## Coordinates, angles and indexes

- **Positions** are in pixels on the map; one map block is 35 pixels.
- **Angles** are in degrees from 0 to 360, counterclockwise from 0 = east.
  `turnLeft` increases the heading and `turnRight` decreases it.
  *Heading* is where the ship points and *tracking* is where it is moving.
- **Enemies by index:** `enemyDistance(0)`, `screenEnemyX(0)` and the other
  index functions describe the ships on your screen, sorted by distance, so
  index 0 is the closest. With no enemy at an index, distances are 9999 and
  positions are -1.
- **Enemies by ID:** the `...Id` functions take a player ID instead, such as
  the one from `closestShipId()`.
- **Off-screen ships:** only ships on your screen are tracked. On a large map
  enemies can be out of view for a long time; `closestRadarX`/`Y` give the
  closest ship on the radar instead.
- **Shots** are sorted by danger, so `shotAlert(0)` is the most dangerous shot.

## Examples

These Spinner bots turn left forever.

Python, run with `python3 Spinner.py` from a folder that contains the module:

```python
import libpyAI as ai

def AI_loop():
    ai.turnLeft(1)

ai.start(AI_loop, ["-name", "Spinner", "-join", "localhost"])
```

Java: compile with `javac Spinner.java javaAI.java` and run with
`java -Djava.library.path=. Spinner`. Keep `javaAI.java` and the native library
in the same folder:

```java
class Spinner extends javaAI {
    @Override
    public void AI_loop() {
        turnLeft(1);
    }
    public Spinner(String args[]) {
        super(args);
    }
    public static void main(String args[]) {
        new Spinner(new String[] {"-name", "Spinner", "-join", "localhost"});
    }
}
```

The `javaAI` constructor runs the whole game, before your subclass's fields are
initialized. Keep the bot's state in `static` fields; see
`bots/geneticAI/xpilotGA/Production.java`.

C, passing the client options on the command line:

```c
#include "cAI.h"

void AI_loop() {
    turnLeft(1);
}

int main(int argc, char *argv[]) {
    return start(argc, argv);
}
```

Build it on macOS with
`clang -I mac/bin Spinner.c -L mac/bin -lcAI -Wl,-rpath,"$PWD/mac/bin" -o Spinner`,
then run `./Spinner -name Spinner -join localhost`.

## Functions

Functions with no value in the *Returns* column return nothing. Key functions
that take a `flag` hold the key with 1 and release it with 0.

### Game control

| Function | Returns | Description |
|---|---|---|
| `start(loop, args)` | int | Connect with the client options in `args` (a list of strings such as `["-name", "Bot", "-join", "localhost"]`) and call `loop()` once per frame. Blocks until the game ends and returns the client's exit status. Only once per process. |
| `switchLoop(loop)` |  | Replace the function called each frame. Python only. |
| `headlessMode()` |  | Don't open the game window. Call before `start`. An X server is still required. |
| `quitAI()` |  | Leave the game; `start` returns after the current frame. |
| `pauseAI()` |  | Press the pause key: your ship leaves play until you unpause. |

### Movement

| Function | Returns | Description |
|---|---|---|
| `turnLeft(flag)` |  | Hold (1) or release (0) the turn-left key. Turning left increases the heading. |
| `turnRight(flag)` |  | Hold (1) or release (0) the turn-right key. |
| `turn(deg)` |  | Turn by `deg` this frame using mouse-style steering, clamped to the maximum turn speed. Positive turns left. |
| `turnToDeg(deg)` |  | Turn toward the absolute heading `deg`, slowing down as it gets close. Call every frame until reached. |
| `thrust(flag)` |  | Hold (1) or release (0) the thrust key. |
| `setTurnSpeed(s)` |  | Set the turn speed (4.0 to 64.0). |
| `setTurnSpeedDeg(s)` |  | Set the turn speed in degrees. |
| `setPower(s)` |  | Set the thrust power (5.0 to 55.0). |
| `getTurnSpeed()` | float | Current turn speed. |
| `getPower()` | float | Current thrust power. |
| `fasterTurnrate()` |  | Increase the turn speed one step. |
| `slowerTurnrate()` |  | Decrease the turn speed one step. |
| `morePower()` |  | Increase the thrust power one step. |
| `lessPower()` |  | Decrease the thrust power one step. |
| `swapSettings()` |  | Swap between the two banks of turn speed and power settings. |
| `emergencyThrust()` |  | Use the emergency thrust item for a temporary speed boost. |
| `toggleAutopilot()` |  | Use the autopilot item to bring the ship to a stop. |
| `hyperjump()` |  | Use the hyperjump item to warp to a random location. |
| `keyHome()` |  | Make the base the ship is sitting on its new home base (respawn point). The ship must be stationary on it. |
| `selfDestruct()` |  | Start the self-destruct countdown. |

### Weapons

| Function | Returns | Description |
|---|---|---|
| `fireShot()` |  | Fire a shot. Shots are limited by the reload time, see `selfReload`. |
| `fireMissile()` |  | Fire a smart missile. |
| `fireTorpedo()` |  | Fire a torpedo. |
| `fireHeat()` |  | Fire a heat-seeking missile. |
| `fireLaser()` |  | Fire the laser. |
| `dropMine()` |  | Drop a stationary mine. |
| `detachMine()` |  | Release a mine that drifts with the ship's velocity. |
| `detonateMines()` |  | Detonate your released mines. |
| `toggleNuclear()` |  | Toggle nuclear weapons (uses several mines or missiles at once). |
| `togglePower()` |  | Toggle the weapon power modifier. |
| `toggleVelocity()` |  | Toggle the explosion velocity modifier for mines and missiles. |
| `toggleCluster()` |  | Toggle cluster weapons. |
| `toggleMini()` |  | Toggle the mini modifier (several smaller weapons). |
| `toggleSpread()` |  | Toggle the spread modifier. |
| `toggleLaser()` |  | Switch between the stun laser and the blinding laser. |
| `toggleImplosion()` |  | Toggle implosion: explosions pull players in instead of pushing them away. |
| `loadModifiers1()` |  | Load modifier bank 1. |
| `loadModifiers2()` |  | Load modifier bank 2. |
| `loadModifiers3()` |  | Load modifier bank 3. |
| `loadModifiers4()` |  | Meant to load modifier bank 4, but loads bank 1 (an upstream bug in the method table). |
| `clearModifiers()` |  | Clear all weapon modifiers. |
| `reprogram()` |  | Reprogram a modifier or lock bank. |

### Defense and items

| Function | Returns | Description |
|---|---|---|
| `shield()` |  | Toggle the shield. |
| `emergencyShield()` |  | Use the emergency shield item for temporary protection. |
| `cloak()` |  | Toggle the cloaking device. |
| `ecm()` |  | Launch an ECM that temporarily blinds nearby opponents. |
| `deflector()` |  | Use the deflector to push everything away from the ship. |
| `phasing()` |  | Use the phasing item to pass through walls. |
| `transporter()` |  | Use the transporter to steal an opponent's item or fuel. |
| `tractorBeam(flag)` |  | Hold (1) or release (0) the tractor beam, which pulls ships in. |
| `pressorBeam(flag)` |  | Hold (1) or release (0) the pressor beam, which pushes ships away. |
| `refuel(flag)` |  | Hold (1) or release (0) the refuel key at a fuel station. |
| `repair()` |  | Repair the target you are next to. |
| `tankDetach()` |  | Detach a fuel tank. |
| `nextTank()` |  | Switch to the next fuel tank. |
| `prevTank()` |  | Switch to the previous fuel tank. |
| `selectItem()` |  | Select the item to drop. |
| `loseItem()` |  | Drop the selected item. |

### Your ship

| Function | Returns | Description |
|---|---|---|
| `selfX()` | int | X position in pixels (one map block is 35 pixels). |
| `selfY()` | int | Y position in pixels. |
| `selfRadarX()` | int | X position on the radar. |
| `selfRadarY()` | int | Y position on the radar. |
| `selfVelX()` | int | X velocity in pixels per frame. |
| `selfVelY()` | int | Y velocity in pixels per frame. |
| `selfSpeed()` | float | Speed in pixels per frame. |
| `selfHeadingDeg()` | float | Direction the ship points, in degrees (0 = east, counterclockwise). |
| `selfHeadingRad()` | float | Direction the ship points, in radians. |
| `selfTrackingDeg()` | float | Direction the ship is moving, in degrees. Equals the heading when the ship is still. |
| `selfTrackingRad()` | float | Direction the ship is moving, in radians. |
| `selfAlive()` | int | 1 while your ship is on screen and alive, otherwise 0. |
| `selfID()` | int | Your player ID. |
| `selfTeam()` | int | Your team number. |
| `selfLives()` | int | Lives left. |
| `selfShield()` | int | Shield status. |
| `selfName()` | str | Your player name. |
| `selfScore()` | float | Your score. |
| `selfReload()` | int | Frames until you can fire again. |

### Lock-on

| Function | Returns | Description |
|---|---|---|
| `lockNext()` |  | Lock on to the next ship. |
| `lockPrev()` |  | Lock on to the previous ship. |
| `lockClose()` |  | Lock on to the closest ship. |
| `lockNextClose()` |  | Lock on to the next-closest ship. |
| `loadLock1()` |  | Load saved lock 1. |
| `loadLock2()` |  | Load saved lock 2. |
| `loadLock3()` |  | Load saved lock 3. |
| `loadLock4()` |  | Load saved lock 4. |
| `lockHeadingDeg()` | float | Direction to the locked ship, in degrees. |
| `lockHeadingRad()` | float | Direction to the locked ship, in radians. |
| `selfLockDist()` | int | Distance to the locked ship. |

### Enemies by index

| Function | Returns | Description |
|---|---|---|
| `enemyDistance(idx)` | float | Distance to enemy `idx`. 9999 when there is no such enemy. |
| `screenEnemyX(idx)` | int | X position of enemy `idx`, or -1. |
| `screenEnemyY(idx)` | int | Y position of enemy `idx`, or -1. |
| `aimdir(idx)` | int | Heading in degrees that would hit enemy `idx`, leading it by its velocity. -1 until the enemy has been tracked for a few frames. |
| `enemySpeed(idx)` | float | Speed of enemy `idx` in pixels per frame. |
| `enemyTrackingDeg(idx)` | float | Direction enemy `idx` is moving, in degrees. |
| `enemyTrackingRad(idx)` | float | Direction enemy `idx` is moving, in radians. |
| `enemyHeadingDeg(idx)` | float | Direction enemy `idx` points, in degrees. |
| `enemyHeadingRad(idx)` | float | Direction enemy `idx` points, in radians. |
| `enemyReload(idx)` | int | Estimated frames until enemy `idx` can fire. |
| `enemyShield(idx)` | int | 1 if enemy `idx` has its shield up, otherwise 0. |
| `enemyLives(idx)` | int | Lives left for enemy `idx`. |
| `enemyTeam(idx)` | int | Team of enemy `idx`. |
| `enemyName(idx)` | str | Name of enemy `idx`. |
| `enemyScore(idx)` | float | Score of enemy `idx`. |

### Enemies by ship ID

| Function | Returns | Description |
|---|---|---|
| `closestShipId()` | int | ID of the closest ship on screen, or -1. |
| `enemyDistanceId(id)` | float | Distance to the ship with ID `id`. |
| `screenEnemyXId(id)` | int | X position of ship `id`. |
| `screenEnemyYId(id)` | int | Y position of ship `id`. |
| `enemySpeedId(id)` | float | Speed of ship `id` in pixels per frame. |
| `enemyTrackingDegId(id)` | float | Direction ship `id` is moving, in degrees. |
| `enemyTrackingRadId(id)` | float | Direction ship `id` is moving, in radians. |
| `enemyHeadingDegId(id)` | float | Direction ship `id` points, in degrees. |
| `enemyHeadingRadId(id)` | float | Direction ship `id` points, in radians. |
| `enemyReloadId(id)` | int | Estimated frames until ship `id` can fire. |
| `enemyShieldId(id)` | int | 1 if ship `id` has its shield up, otherwise 0. |
| `enemyLivesId(id)` | int | Lives left for ship `id`. |
| `enemyTeamId(id)` | int | Team of ship `id`, or -1 on a map without teams. |
| `enemyNameId(id)` | str | Name of ship `id`. |
| `enemyScoreId(id)` | float | Score of ship `id`. |

### Radar and items

| Function | Returns | Description |
|---|---|---|
| `closestRadarX()` | int | Radar X coordinate (0 to 256) of the closest ship on the radar. |
| `closestRadarY()` | int | Radar Y coordinate (0 to 256) of the closest ship on the radar. |
| `closestItemX()` | int | X position of the closest item on screen. |
| `closestItemY()` | int | Y position of the closest item on screen. |

### Walls

| Function | Returns | Description |
|---|---|---|
| `wallFeeler(dist, angle)` | int | Distance to the nearest wall in direction `angle` (degrees), looking up to `dist` pixels. Returns `dist` when there is no wall in range. |
| `wallFeelerRad(dist, rad)` | int | Same as `wallFeeler`, with the angle in radians. |
| `wallBetween(x1, y1, x2, y2)` | float | Distance from (x1, y1) to the first wall on the line to (x2, y2), or -1 if the line is clear. The Java version takes two extra flag arguments, which are ignored. |

### Shots

| Function | Returns | Description |
|---|---|---|
| `shotAlert(idx)` | int | Danger rating of shot `idx`: its predicted closest approach plus time to impact × 5. Lower is more dangerous; 30000 means it is moving away and -1 that there is no such shot. |
| `shotX(idx)` | int | X position of shot `idx`. |
| `shotY(idx)` | int | Y position of shot `idx`. |
| `shotDist(idx)` | int | Distance from your ship to shot `idx`. |
| `shotVel(idx)` | int | Speed of shot `idx`. |
| `shotVelDir(idx)` | int | Direction shot `idx` is moving, in degrees. |

### Angles

| Function | Returns | Description |
|---|---|---|
| `degToRad(deg)` | float | Degrees to radians. |
| `radToDeg(rad)` | int | Radians to degrees. |
| `angleDiff(angle1, angle2)` | int | `angle2 - angle1`, normalized to -180..180. Positive means `angle2` is counterclockwise (turn left). |
| `angleAdd(angle1, angle2)` | int | `(angle1 + angle2) % 360`. |

### Messages and HUD

| Function | Returns | Description |
|---|---|---|
| `talk(message)` |  | Send a chat message. |
| `talkKey()` |  | Open the chat input. |
| `scanMsg(id)` | str | Chat message number `id`, or an empty string. |
| `scanGameMsg(id)` | str | Game-event message number `id` (kills, deaths and so on), or an empty string. |
| `hud(i)` | str | Name shown in HUD slot `i`, if any. |
| `hudScore(i)` | str | Score shown in HUD slot `i`, if any. |
| `hudTimeLeft(i)` | int | Seconds the HUD will keep showing slot `i`. |
| `toggleShowMessage()` |  | Toggle messages on the HUD. |
| `toggleShowItems()` |  | Toggle items on the HUD. |
| `toggleCompass()` |  | Toggle the compass. |
| `toggleUserName()` |  | Toggle showing players' real user names instead of their nicknames. |

### Capture the flag

| Function | Returns | Description |
|---|---|---|
| `connector(flag)` |  | Hold (1) or release (0) the connector key to attach to the ball. |
| `dropBall()` |  | Drop the ball. |
| `ballX()` | int | X position of the ball. |
| `ballY()` | int | Y position of the ball. |
| `connectorX0()` | int | X position of one end of the ball connector. |
| `connectorY0()` | int | Y position of one end of the ball connector. |
| `connectorX1()` | int | X position of the other end of the ball connector. |
| `connectorY1()` | int | Y position of the other end of the ball connector. |

