# Bots

Every bot needs a running server: start one with `mac/server.sh` (or
`./xpilots -map maps/simple.xp +reportMeta` on Linux). Then run the bot from its
own folder, which holds a copy of the AI library after `mac/build.sh` (see the
[top-level README](../README.md)). Most bots join `localhost` on their own. The
two Spinner examples don't, so their client opens a server picker window.

| Bot | Language | Approach | Run from its folder |
|---|---|---|---|
| [`Spinner.py`, `Spinner.java`](#examples) | Python, Java | Example: turns forever | `python3 Spinner.py` / `java -Djava.library.path=. Spinner` |
| [`bob.py`](#rule-based-bots) | Python | Rules: reacts to the nearest wall, bullet or player | `python3 bob.py` |
| [`expertAI/expertBot.py`](#rule-based-bots) | Python | Production system: wall feelers and aimed fire | `python3 expertBot.py` |
| [`fuzzyBot.py`, `FuzzyHelpPrime.py`, `fuzzyAI/fuzzyBot.py`](#fuzzy-logic-bots) | Python | Fuzzy logic controller | `python3 fuzzyBot.py` |
| [`gen_alg/russell_GA.py`](#genetic-algorithms) | Python | Genetic algorithm on OneMax (no game) | `python3 russell_GA.py` |
| [`geneticAI/basicGA`](#genetic-algorithms) | Java | Genetic algorithm on OneMax (no game) | `javac GeneticAlgorithm.java && java GeneticAlgorithm` |
| [`geneticAI/xpilotGA`](#xpilotga-evolving-the-expert-bot) | Java | Genetic algorithm that tunes the expert bot | see below |
| [`perceptron/`](#neural-networks) | Python, Java | Perceptron and a small neural network (no game) | `python3 perceptron.py` |
| [`neuralAI/perceptron`, `neuralNet`, `multiLayerPercerptron`](#neural-networks) | Java | Perceptron and neural networks (no game) | `javac *.java`, then run the trainer (see below) |
| [`neuralAI/neuralHelp`](#neuralhelp-a-network-that-learned-from-the-fuzzy-bot) | Python, Java | Neural network trained on the fuzzy bot's play | see below |

The authors are named at the top of each file. Most bots are by Russell
Kosovsky and Jay Nash for COM407 (2023); the examples and `javaAI.java` come
from the Xpilot-AI team.

## Examples

`Spinner.py` and `Spinner.java` are the Xpilot-AI examples: they hold the
turn-left key forever. `javaAI.java` is the Java side of the AI library, which
every Java bot extends.

## Rule-based bots

**`bob.py`** feels for walls in eight directions plus the direction of travel.
It finds the nearest threat (wall, bullet or player), sets its thrust power by
how close that threat is, and reacts to it: it turns away from walls, turns and
thrusts to dodge bullets, and turns toward players while firing.

**`expertAI/expertBot.py`** is a production system: an ordered list of
if-then rules, where the first rule that matches decides the action.

- **Sensing:** it adds up three wall feelers (center and ±10°) in each of four
  directions, plus three along its direction of travel.
- **Thrust:** it thrusts when the way ahead is open and it is slower than 15,
  or when it is about to hit a wall it is drifting toward.
- **Turning:** it turns to aim at an enemy within 300 pixels, otherwise toward
  the more open side, or against its drift when a wall is close.
- **Firing:** it fires when its heading is within 5° of `aimdir(0)`.

`geneticAI/xpilotGA/expertBot.py` is an identical copy.

## Fuzzy logic bots

`fuzzyBot.py`, `FuzzyHelpPrime.py` and `fuzzyAI/fuzzyBot.py` (a copy of
`fuzzyBot.py`) are fuzzy logic controllers:

1. **Fuzzification:** wall distances, alignment with the enemy and enemy
   distance become degrees of membership in sets such as near and far.
2. **Rules:** fuzzy rules combine those memberships.
3. **Defuzzification:** the result is turned back into turn, thrust and fire
   decisions.

`FuzzyHelpPrime.py` is another version of the same controller.

## Genetic algorithms

**`gen_alg/russell_GA.py`** and **`geneticAI/basicGA`** solve OneMax: they
evolve 64-bit strings toward all ones. They exercise the genetic algorithm
without the game.

| | `russell_GA.py` | `basicGA` |
|---|---|---|
| Population | 200 | 200 |
| Selection | tournament of 5 | tournament of 4 |
| Mutation rate | 0.001 | 0.01 |
| Starting population | `initial_population.txt` if present, otherwise random | `population.txt` |
| Output | `final_population.txt` | `final_population.txt`, `checkpoints/` every 10 generations, `rawData/` every generation |

### xpilotGA: evolving the expert bot

`geneticAI/xpilotGA` uses a genetic algorithm to tune the thresholds in the
expert bot's rules.

- **`Production.java`** is the expert bot rewritten in Java. Its thresholds come
  from a 90-bit chromosome of 15 six-bit genes.
- **`GeneticAlgorithm.java`** evolves those chromosomes. It scores each one by
  playing a game with it.

| Gene | Threshold | Scale |
|---|---|---|
| 0 | speed limit for thrusting | gene |
| 1 | open distance ahead to thrust | gene × 50 |
| 2 | wall distance along the direction of travel that triggers thrust | gene × 15 |
| 3, 4 | maximum and minimum heading–travel angle for that thrust | gene × 5 |
| 5 | rear wall distance that triggers thrust | gene |
| 6 | enemy distance to engage | gene × 10 |
| 7 | wall clearance needed to engage | gene × 5 |
| 8 | open distance for turning toward the open side | gene × 20 |
| 9, 10 | low and medium speed thresholds | gene |
| 11 | aim error in degrees within which to fire | gene |
| 12 | wall distance that counts as danger | gene × 20 |
| 13 | wall distance that counts as close | gene × 10 |
| 14 | wall clearance needed to keep aiming | gene × 3 |

For each chromosome, `GeneticAlgorithm` starts `java Production <chromosome>` as
a separate process, because the client can only start once per process.
Production plays until it has died 3 times or 2000 frames have passed, then
prints `FITNESS <score>`, and that score is the chromosome's fitness.
Selection is roulette-wheel, with the weights shifted so that zero and
negative scores still work. Crossover uses one point, and the mutation rate is
0.001.

To run it:

```sh
mac/server.sh simple.xp -robots 2                 # server with robot opponents
cd bots/geneticAI/xpilotGA
javac *.java
java -Djava.library.path=. GeneticAlgorithm 20 10   # population size, generations
java -Djava.library.path=. Production 100001101010100110110011100110011011010110011010101101010110110010101010110011100001011010
```

The last command plays a single game with one chromosome.

Things to know:

- **Run time:** each game takes up to about 2.5 minutes at 14 frames per
  second. The defaults (200 chromosomes for 1000 generations) would take days.
- **Opponents:** score only changes through kills and deaths, so the server
  needs opponents, such as `-robots N` or another bot.
- **Output files:** results go to `final_population.txt` and `checkpoints/`.
  `population.txt` holds 64-bit OneMax chromosomes from `basicGA`, so it can't
  seed this GA.

## Neural networks

The exercises in `perceptron/` and in `neuralAI/` (except `neuralHelp`) don't
use the game. They learn functions of 5 binary inputs:

- **Perceptron:** output 1 when at least 4 of the 5 inputs are 1. This is
  linearly separable, so a single perceptron can learn it.
- **Multilayer networks:** output 1 when at least 4 inputs are 1 *or* at most 1
  is. This isn't linearly separable, so it needs hidden layers.

| Folder | Contents |
|---|---|
| `perceptron/` | `perceptron.py` and `Perceptron.java`: a perceptron, first with hand-set weights and then trained. `nn.py`: a network with two hidden layers in numpy (`python3 -m pip install --user numpy`) |
| `neuralAI/perceptron` | Java perceptron: `neuronTest` uses hand-set weights, `neuronTrain` learns them |
| `neuralAI/neuralNet` | Java network with configurable layers (`Network`, `HiddenLayer`, `OutputLayer`, `Neuron`), trained by `Test` |
| `neuralAI/multiLayerPercerptron` | A second Java multilayer network, trained by `neuronTrain` |

### neuralHelp: a network that learned from the fuzzy bot

`neuralAI/neuralHelp` trains a network to imitate the fuzzy bot, then plays
with it:

1. **Collect:** `python3 dataCollect.py` plays as the fuzzy bot without a
   window. Each frame it is alive with an enemy in range, it appends 15 inputs
   to `inputs_15_4.txt`: wall feelers, alignment, enemy distance and so on. It
   appends the fuzzy bot's 4 decisions (thrust, turn left, turn right, fire)
   to `outputs_15_4.txt`. The bot needs an opponent to collect anything.
2. **Train:** `javac fuzzyTrain.java Network.java HiddenLayer.java OutputLayer.java Neuron.java && java fuzzyTrain`
   trains a network (15 inputs, 4 outputs, hidden layers of 12) for 1000
   epochs. It prints the accuracy and saves `net_15.ser`.
3. **Play:** `javac *.java && java -Djava.library.path=. NeuralHelp` loads
   `net_best_93_21.ser`, the best network saved so far, and plays with it. To
   play with a new network, copy it over that file or change the file name in
   `NeuralHelp.java`.

`net.ser` is an earlier network. `outputs.txt` holds older training outputs;
its matching inputs file isn't in the repository.
