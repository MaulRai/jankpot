# Enemy AI and Strategy Skills

This document details the decision-making algorithms, weight-based card selections, and specific battle behaviors of all enemies in the Jank Pot card battle game. Use this reference to understand and train AI agents against rival strategy types.

---

## AI System Architecture

Enemy actions are governed by a combination of weighted deck builds and real-time state evaluation:

```
                  ┌──────────────────────────────┐
                  │        EnemyCatalog          │
                  │   (Loads Enemy Definitions)  │
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │       EnemyController        │
                  │ (Manages HP, Hand, Spawning) │
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │    EnemyStrategyContext      │
                  │  (Stores Turn & State Info)  │
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │   EnemyStrategyEvaluator     │
                  │ (Computes Play Probability)  │
                  └──────────────────────────────┘
```

---

## Strategy Catalog

Every enemy has a designated `strategy_id` defined in its resource def. The `EnemyStrategyEvaluator` translates this ID into turn-by-turn probabilities for **Rock**, **Paper**, and **Scissors**.

### 1. Simple Biased Strategies
These enemies favor a specific type of card and compile their starting decks with higher ratios of that type:

| Strategy ID | Primary Type | Weight Distribution | Deck Count Ratio [R, P, S] | Common Enemies |
|-------------|--------------|---------------------|----------------------------|----------------|
| `rock_bias` | ROCK | `[55%, 25%, 20%]` | `[5, 2, 2]` | Pebble Grunt |
| `paper_bias`| PAPER | `[20%, 55%, 25%]` | `[2, 5, 2]` | Paper Moth |
| `scissors_bias` | SCISSORS | `[25%, 20%, 55%]` | `[2, 2, 5]` | Tin Cutter |

---

### 2. Reactive & Contextual Strategies
These AI types adjust their play weights based on the player's last action, previous clash results, or their own health status:

#### `dice_imp`
- **Behavior:** Detests repetition.
- **Logic:** Evaluates the last card type played by itself. It gives that type a low weight (`20%`) and splits the remaining weight (`48.5%` each) between the other two types.
- **Objective:** Constantly rotate card choices to remain unpredictable.

#### `echo`
- **Behavior:** Repeats actions when losing or drawing.
- **Logic:**
  - If the last round was a **loss**: 65% chance to repeat its own last played card.
  - If the last round was a **draw**: 45% chance to repeat its last played card.
  - Otherwise: Balanced (`33%` each).

#### `counter_player`
- **Behavior:** Attempts to beat the player's last card type.
- **Logic:** Reads the player's last played card type and weighs its counter heavily:
  - Counter Type: `65%`
  - Same Type: `20%`
  - Losing Type: `15%`

#### `mirror_player`
- **Behavior:** Copies the player's last card type.
- **Logic:** Reads the player's last played card type and weighs it heavily:
  - Same Type: `60%`
  - Counter Type: `20%`
  - Losing Type: `20%`

#### `avoid_last`
- **Behavior:** Actively avoids its last played card type.
- **Logic:** Gives its own last played card type a minimal `10%` weight, and splits `45%` each between the other two choices.

#### `bruise_toad`
- **Behavior:** Opportunistic punisher.
- **Logic:**
  - If it **won** the last round: 70% chance to counter the player's last played card type.
  - Otherwise: Plays a balanced mix (`[35%, 30%, 35%]`).

#### `blood_magpie`
- **Behavior:** Stubborn loser.
- **Logic:**
  - If it **lost** the last round: 70% chance to repeat its own last played card type.
  - Otherwise: Plays a balanced mix (`33%` each).

---

### 3. Phased & Complex Boss Strategies

#### `gambler`
- **Behavior:** Hoards and unleashes upgraded/high-rarity weapons.
- **Logic:**
  - Every **3rd turn**: Identifies the highest-rarity card in its hand and plays that card type with a high weight (`70%`).
  - Other turns: Boosts the play weight of all upgraded (non-basic) cards currently in its hand by `25.0`.

#### `fog_witch`
- **Behavior:** Cycles focus type.
- **Logic:** Divides the battle into 3-turn phases. At the start of each phase, it picks a random card type to favor, giving it `55%` weight (and `25%/20%` to the others) for those 3 turns.

#### `ledger` (Ledger Golem)
- **Behavior:** Cyclic accountant.
- **Logic:** Follows a strict turn cycle. It prefers the type matching `(turn_count % 3)` (0 = Rock, 1 = Paper, 2 = Scissors) with `75%` weight, and other types with `12.5%`.

#### `mad_hatter` (Mad Hatter Boss)
- **Behavior:** Highly erratic, shifting styles every 3 turns.
- **Logic:** Changes phases in a 4-phase cycle:
  - **Phase 0:** Balanced (`33%` each).
  - **Phase 1:** Mirrors the player's last played card type (`60%`).
  - **Phase 2:** Counters the player's last played card type (`65%`).
  - **Phase 3:** Strong Paper bias (`60%` Paper, `20%` others).

#### `hatter_mimic`
- **Behavior:** Deceptive advertiser.
- **Logic:** Chooses a random card type to "advertise" on its status (its face) at start of battle. However, it splits its play weight equally (`46%` each) between that advertised type and the type that *counters* it.

#### `iron_tortoise`
- **Behavior:** Fortifies when damaged.
- **Logic:**
  - Normal state: Moderate Rock bias (`[50%, 30%, 20%]`).
  - Low health (**HP <= 3**): Heavy Rock bias (`[70%, 20%, 10%]`).

#### `guillotine_duke`
- **Behavior:** Punishes Paper plays.
- **Logic:**
  - Standard state: Heavy Scissors bias (`[25%, 20%, 55%]`).
  - If player played **Paper** last turn: Scissors weight rises to a massive `75%` (`[15%, 10%, 75%]`).

---

## Strategic Counter-Cheat Sheet

For training AI agents to defeat these strategies:

| Enemy Strategy | Best Counter Strategy |
|----------------|----------------------|
| `rock_bias` / `iron_tortoise` | Play **Paper** heavy. |
| `paper_bias` / `mad_hatter` (Phase 3) | Play **Scissors** heavy. |
| `scissors_bias` / `guillotine_duke` | Play **Rock** heavy. Avoid Paper when Duke prepares. |
| `dice_imp` / `avoid_last` | Predict that the enemy will *not* repeat its last card type. |
| `echo` / `blood_magpie` | If the enemy lost, expect them to play the same card. Play the counter to it. |
| `counter_player` | Play the type that beats their expected counter (i.e. play what loses to your own last card). |
| `mirror_player` | Play the counter to your own last card. |
| `bruise_toad` | If you lost, expect them to counter your last card. Play the type that beats that counter. |
| `ledger` | Cycle through [Paper, Scissors, Rock] matching the 3-turn pattern. |
| `hatter_mimic` | Play the counter to their counter (which beats both their advertised face and their counter). |
