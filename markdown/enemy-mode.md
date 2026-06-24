# Enemy Behavior Catalog for RPS Deckbuilder

## Global Enemy AI Rule

Each enemy should choose a card using weighted probabilities.

Enemy decision flow:

1. Read battle context:

   * enemy last played type
   * player last played type
   * last winner
   * current clash count
   * enemy HP
   * player HP
   * available enemy cards
   * disabled/concealed options
2. Generate weight for Rock, Paper, Scissors.
3. Remove disabled options.
4. If a preferred card type is unavailable, normalize the remaining valid options.
5. Randomly choose based on final weights.
6. Pick one available card instance of that type.

Recommended default weights:

```txt
Rock: 33
Paper: 33
Scissors: 33
```

Avoid making normal enemies 100% predictable. Most enemies should have a main behavior around 55–75% probability and random fallback around 25–45%.

---

# Common Enemies

## 1. Pebble Grunt

Short description:

> Often plays Rock.

Detailed behavior:
Pebble Grunt is a simple defensive enemy. It prefers Rock most of the time, but still occasionally plays Paper or Scissors so it is not completely free to counter.

Implementation:

```txt
Rock: 55
Paper: 25
Scissors: 20
```

Use case:
Good first enemy. Teaches player that enemy patterns exist.

---

## 2. Paper Moth

Short description:

> Often plays Paper.

Detailed behavior:
Paper Moth favors Paper. It is weak against Scissors-heavy players, but can punish players who overuse Rock.

Implementation:

```txt
Rock: 20
Paper: 55
Scissors: 25
```

Use case:
Good early enemy for teaching type bias.

---

## 3. Tin Cutter

Short description:

> Often plays Scissors.

Detailed behavior:
Tin Cutter favors Scissors and plays aggressively. It is vulnerable to Rock, but can punish Paper-based builds.

Implementation:

```txt
Rock: 25
Paper: 20
Scissors: 55
```

Use case:
Good early enemy for testing Rock defensive cards.

---

## 4. Dice Imp

Short description:

> Completely unpredictable.

Detailed behavior:
Dice Imp chooses randomly with no long-term pattern. It should be used sparingly, because pure randomness reduces the player’s ability to read the enemy.

Implementation:

```txt
Rock: 33
Paper: 33
Scissors: 33
```

Optional twist:
Every 3 clashes, Dice Imp gets a small temporary bias toward a random type.

Use case:
Good as a chaos enemy, but not ideal as the main enemy style.

---

# Uncommon Enemies

## 5. Echo Goblin

Short description:

> Repeats winning moves.

Detailed behavior:
Echo Goblin tends to repeat the card type that won the previous clash. If it won using Rock, it is likely to play Rock again. If there was no previous winner, use balanced random.

Implementation:

```txt
If enemy won last clash:
  enemy last played type: 65
  other two types: 17.5 each

If player won last clash:
  balanced random

If draw:
  enemy last played type: 45
  other two types: 27.5 each
```

Use case:
Great for RPS mind-game. Player can punish repetition by countering the repeated type.

---

## 6. Vengeful Crow

Short description:

> Counters your last card.

Detailed behavior:
Vengeful Crow watches the player’s previous card and tends to play the type that beats it.

Example:

* If player last played Rock, enemy prefers Paper.
* If player last played Paper, enemy prefers Scissors.
* If player last played Scissors, enemy prefers Rock.

Implementation:

```txt
Counter to player last type: 65
Same as player last type: 20
Losing type: 15
```

If no player last card exists:

```txt
Rock: 33
Paper: 33
Scissors: 33
```

Use case:
Makes the player avoid repeating the same card too often.

---

## 7. Mirror Jester

Short description:

> Copies your last card.

Detailed behavior:
Mirror Jester tends to copy the player’s previous card. This creates many draw situations unless the player predicts the copy and counters it.

Implementation:

```txt
Same as player last type: 60
Counter to player last type: 20
Losing type: 20
```

If no previous player card:

```txt
Rock: 33
Paper: 33
Scissors: 33
```

Use case:
Good enemy for making draw effects like Sculptural Sheet feel valuable.

---

## 8. Cowardly Knight

Short description:

> Plays safer when low HP.

Detailed behavior:
Cowardly Knight changes behavior based on HP. At high HP, it plays balanced. At low HP, it favors Rock because Rock is associated with defense and resistance.

Implementation:

```txt
If enemy HP > 3:
  Rock: 33
  Paper: 33
  Scissors: 33

If enemy HP <= 3:
  Rock: 60
  Paper: 25
  Scissors: 15
```

Optional:
If enemy has a defensive Rock card available, increase Rock weight further.

Use case:
Good for teaching players that enemy behavior can change mid-battle.

---

## 9. Duelist Finch

Short description:

> Avoids repeating itself.

Detailed behavior:
Duelist Finch dislikes playing the same type twice in a row. It gives low weight to its last played type and prefers the other two.

Implementation:

```txt
Enemy last played type: 10
Other two types: 45 each
```

If no previous card:

```txt
Rock: 33
Paper: 33
Scissors: 33
```

Use case:
Good enemy for players who track card history.

---

## 10. Bruise Toad

Short description:

> Gets aggressive after losing.

Detailed behavior:
Bruise Toad becomes more aggressive after it loses a clash. After losing, it tends to play the type that would beat the player’s winning card from the previous clash.

Example:

* Player won with Paper.
* Enemy is likely to play Scissors next.

Implementation:

```txt
If enemy lost last clash:
  Counter to player last type: 70
  Other two types: 15 each

If enemy won or drew:
  Rock: 35
  Paper: 30
  Scissors: 35
```

Use case:
Creates a readable revenge pattern.

---

# Rare / Advanced Enemies

## 11. Gambler Hare

Short description:

> Takes risky swings.

Detailed behavior:
Gambler Hare prefers high-risk choices. If it has a special upgraded card in hand, it is more likely to use that type, even if the type prediction is not optimal.

Implementation:

```txt
Base:
  Rock: 33
  Paper: 33
  Scissors: 33

If enemy has a rare/upgraded card available:
  upgraded card type +25 weight
  normalize final weights
```

Optional:
Every 3 clashes, force a “gamble turn”:

```txt
Highest damage available type: 70
Other two: 15 each
```

Use case:
Good enemy for making the player fear burst damage.

---

## 12. Fog Witch

Short description:

> Hides its pattern.

Detailed behavior:
Fog Witch changes its behavior every few clashes. It starts with one hidden bias, then rotates to a different bias after 3 clashes. The player must infer the current pattern.

Implementation:

```txt
Every 3 clashes, choose one mode:
  Rock-biased:
    Rock: 55
    Paper: 25
    Scissors: 20

  Paper-biased:
    Rock: 20
    Paper: 55
    Scissors: 25

  Scissors-biased:
    Rock: 25
    Paper: 20
    Scissors: 55
```

Do not show the exact mode directly. Sidebar can say only:

> Changes pattern every 3 clashes.

Use case:
Good mid-run enemy. Works well with Magic Ball.

---

## 13. Ledger Golem

Short description:

> Follows a fixed sequence.

Detailed behavior:
Ledger Golem follows a semi-fixed sequence, but sometimes deviates. This makes it feel mathematical and predictable once the player notices.

Example sequence:

```txt
Rock -> Paper -> Scissors -> Rock -> Paper -> Scissors
```

Implementation:

```txt
Expected sequence type: 75
Other two types: 12.5 each
```

Optional sequence variants:

```txt
Rock -> Rock -> Paper -> Scissors
Paper -> Scissors -> Paper -> Rock
Scissors -> Rock -> Scissors -> Paper
```

Use case:
Good macro-style enemy. Rewards observation.

---

## 14. Hatter Mimic

Short description:

> Lies about its pattern.

Detailed behavior:
Hatter Mimic has a displayed behavior that is partially false. For example, the sidebar may say “Often plays Paper,” but the enemy only follows that behavior 40% of the time and often counters player expectation.

Implementation:

```txt
Displayed preferred type: 40
Counter to displayed counterplay: 40
Random other: 20
```

Example:
If displayed type is Paper, player may choose Scissors to counter it.
Hatter Mimic may instead play Rock to beat Scissors.

Weights:

```txt
Displayed type: 40
Type that beats the expected counter: 40
Remaining type: 20
```

Use case:
Good rare trickster enemy. Do not use too early because it can feel unfair before players learn the game.

---

## 15. Blood Magpie

Short description:

> Repeats if it damages you.

Detailed behavior:
Blood Magpie repeats any card type that successfully dealt damage to the player. If it fails to damage, it becomes random again.

Implementation:

```txt
If enemy dealt damage last clash:
  enemy last played type: 70
  other two types: 15 each

If enemy did not deal damage:
  Rock: 33
  Paper: 33
  Scissors: 33
```

Use case:
Good for punishing players who do not adapt after taking damage.

---

# Boss Enemies

## 16. Mad Hatter

Short description:

> Changes rules every 3 clashes.

Detailed behavior:
Mad Hatter is a Paper/Luck-themed boss. Every 3 clashes, it changes its behavior mode. It can shift between random, copy, counter, and bias patterns.

Implementation:

```txt
Every 3 clashes, switch mode:

Mode 1: Tea Chaos
  Rock: 33
  Paper: 33
  Scissors: 33

Mode 2: Mirror Tea
  Same as player last type: 60
  Other two types: 20 each

Mode 3: Counter Riddle
  Counter to player last type: 65
  Other two types: 17.5 each

Mode 4: Paper Party
  Paper: 60
  Rock: 20
  Scissors: 20
```

Optional boss rule:
Every 3 clashes, one random player option is concealed for 1 clash. Never conceal all available options.

Use case:
Major Paper/Luck boss. Should feel chaotic but still learnable.

---

## 17. Iron Tortoise

Short description:

> Defensive boss that favors Rock.

Detailed behavior:
Iron Tortoise is a Rock/Resistance boss. It prefers Rock, especially at low HP. It punishes reckless Scissors play and is hard to burst down.

Implementation:

```txt
If enemy HP > 3:
  Rock: 50
  Paper: 30
  Scissors: 20

If enemy HP <= 3:
  Rock: 70
  Paper: 20
  Scissors: 10
```

Optional boss rule:
The first damage Iron Tortoise takes every 3 clashes is reduced by 1.

Use case:
Good Rock-themed boss. Encourages Paper/control builds.

---

## 18. Guillotine Duke

Short description:

> Aggressive boss that hunts Paper.

Detailed behavior:
Guillotine Duke is a Scissors/Deadly boss. It prefers Scissors, but if the player used Paper recently, it becomes even more likely to use Scissors.

Implementation:

```txt
Base:
  Rock: 25
  Paper: 20
  Scissors: 55

If player played Paper last clash:
  Rock: 15
  Paper: 10
  Scissors: 75
```

Optional boss rule:
Every 4 clashes, Guillotine Duke’s winning attack deals +1 damage.

Use case:
Good Scissors-themed boss. Forces player to avoid predictable Paper play.

---

# Suggested Enemy Progression

Early run:

* Pebble Grunt
* Paper Moth
* Tin Cutter
* Dice Imp

Mid run:

* Echo Goblin
* Vengeful Crow
* Mirror Jester
* Cowardly Knight
* Duelist Finch
* Bruise Toad

Late run:

* Gambler Hare
* Fog Witch
* Ledger Golem
* Hatter Mimic
* Blood Magpie