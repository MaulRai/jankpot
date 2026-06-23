# RPS Balatro-like Godot Implementation Outline

## Target Game Mode

Implement **Draw Pile Retain Mode**.

Rules:

* Player starts with deck:

  * 3 Rock
  * 3 Paper
  * 3 Scissors
* Hand size: 3.
* Each turn player selects 1 card.
* Played card goes to discard.
* Unplayed cards stay in hand.
* Draw until hand size is full.
* If draw pile is empty, shuffle discard pile back into draw pile.
* Enemy also plays 1 hidden card per turn.
* Resolve using classic Rock Paper Scissors.
* Card effects/modifiers are added later.

Available assets:

* `res://assets/ui/card-base.png`
* `res://assets/ui/card-slot.png`
* `res://assets/weapon/paper-1.png`
* `res://assets/weapon/scissors-1.png`
* `res://assets/weapon/rock-1.png`
* `res://assets/item/magic-ball.png`

---

# Phase 0 — Project Structure and UI Skeleton

Create clean folder structure:

```txt
res://scenes/
  main/
    Main.tscn
  ui/
    CardView.tscn
    CardSlot.tscn
    TooltipBox.tscn
  game/
    BattleBoard.tscn

res://scripts/
  data/
    CardDef.gd
    EffectKeyword.gd
  game/
    GameController.gd
    DeckManager.gd
    BattleResolver.gd
    EnemyController.gd
  ui/
    CardView.gd
    HandView.gd
    TooltipManager.gd
    CardSlot.gd
```

Main layout:

* Left panel: run info, HP, round, coins.
* Center board: player played slot and enemy played slot.
* Bottom: player hand.
* Right: draw pile, discard pile, consumable slot.
* Top: passive item slots.

Use `Control`-based UI, not `Node2D`, so card layout is easier with anchors and containers.

Acceptance criteria:

* Main scene opens with empty UI zones.
* Placeholder panels exist for left info, board, hand, deck, discard, and item slots.
* UI scales properly on 16:9 resolution.

---

# Phase 1 — Card Data and Card Rendering

Create `CardDef.gd` as a Resource-like data class.

Card fields:

* `id`
* `card_type`: `"rock"`, `"paper"`, `"scissors"`
* `name`
* `brief_description`
* `art_path`
* `background_color`
* `keywords`
* `effects`

Create initial card data:

* Rock
* Paper
* Scissors

Card visual layout:

* Card size: based on `card-base.png`, 320x480.
* Top image panel:

  * Position around top half.
  * Has inner margin.
  * Has type-colored background.
  * Has outline separating it from card body.
* Body:

  * Card name.
  * Brief description.
  * Highlighted keywords using colored text.

Recommended type colors:

* Scissors: muted red, not too bright.
* Paper: pastel yellow.
* Rock: grey-blue.

Example:

* Scissors background: `#9A4A4A`
* Paper background: `#E7DFA4`
* Rock background: `#7E91A3`

Acceptance criteria:

* CardView can render Rock, Paper, and Scissors using the correct asset.
* Art appears in the top half of the card.
* Name and description appear in the lower half.
* Each card has a distinct but soft type background.

---

# Phase 2 — Hand System and Card Layout

Implement `DeckManager.gd`.

State:

* `draw_pile`
* `hand`
* `discard_pile`

Functions:

* `setup_starting_deck()`
* `shuffle_draw_pile()`
* `draw_until_full(hand_size)`
* `play_card(card_id)`
* `discard_played_card(card)`
* `reshuffle_discard_if_needed()`

Implement `HandView.gd`.

Hand behavior:

* Cards appear at bottom center.
* Cards are slightly fanned.
* Middle card is highest.
* Each card has small rotation based on index.
* Hovered card:

  * moves upward
  * scales slightly
  * z-index increases
* Selected card:

  * gets stronger outline/glow
  * can be clicked again to confirm play

Acceptance criteria:

* Player starts with 3 cards in hand.
* Clicking a card selects it.
* Confirming play removes it from hand and moves it to played slot.
* Unplayed cards stay in hand.
* A new card is drawn to refill hand.

---

# Phase 3 — Battle Board and Play Animation

Create two card slots in the center:

* Player played slot
* Enemy played slot

Use `card-slot.png` as the base slot visual.

Turn flow:

1. Player selects card.
2. Enemy chooses hidden card.
3. Player card animates from hand to player slot.
4. Enemy card appears face-down or hidden.
5. Enemy card flips/reveals.
6. RPS result is resolved.
7. Damage text appears.
8. Played cards move to discard.

Animation requirements:

* Card movement uses Tween.
* Use easing such as `TRANS_BACK`, `TRANS_CUBIC`, or `TRANS_SINE`.
* Card should slightly rotate during movement.
* On reveal, enemy card should flip or scale X from 1 to 0 to 1.
* On hit, damaged side should shake briefly.
* Damage number floats upward and fades.

Acceptance criteria:

* Playing a card feels animated, not instant.
* Enemy reveal has clear timing.
* Result is readable.
* Cards go to discard after resolution.

---

# Phase 4 — RPS Resolver and Basic Damage

Implement `BattleResolver.gd`.

Rules:

* Rock beats Scissors.
* Scissors beats Paper.
* Paper beats Rock.
* Draw normally deals no damage.
* Winner deals 1 damage.

State:

* Player HP
* Enemy HP
* Turn count
* Round status

Acceptance criteria:

* Game can resolve Rock/Paper/Scissors correctly.
* HP updates correctly.
* Draw condition works.
* Battle ends when one side reaches 0 HP.

---

# Phase 5 — Rich Description and Keyword Tooltip

Use `RichTextLabel` for card descriptions.

Keyword examples:

* `[color=#FF7777]Damage[/color]`
* `[color=#B77DFF]Luck[/color]`
* `[color=#66CCFF]Reveal[/color]`
* `[color=#FF5555]Bleed[/color]`
* `[color=#AAAAFF]Conceal[/color]`

Create `TooltipManager.gd`.

Tooltip behavior:

* When hovering a card, show extra info for highlighted keywords.
* Tooltip appears near the mouse or beside the card.
* Tooltip should not cover the card.
* Tooltip fades in/out quickly.

Example keyword glossary:

```txt
Damage: Reduces enemy HP.
Luck: Increases chance-based effects.
Reveal: Shows hidden enemy information.
Bleed: Deals damage at the end of turns.
Conceal: Disables or hides an option.
```

Implementation note:

* First version may show all keyword explanations when hovering the card.
* Later version can support per-word hover using RichTextLabel meta tags.

Acceptance criteria:

* Highlighted words are colored differently.
* Hovering a card shows keyword explanation.
* Tooltip disappears when card is no longer hovered.

---

# Phase 6 — Magic Ball Consumable

Add item slot on the right side.

Implement Magic Ball:

* Uses `res://assets/item/magic-ball.png`.
* One-time use.
* Predicts enemy next card.
* 80% chance prediction is correct.
* 20% chance prediction is wrong.

UI:

* Magic Ball sits in a consumable slot.
* On hover, show description.
* On click, activate it.
* Show prediction text or icon:

  * “Enemy may play Rock”
  * “Enemy may play Paper”
  * “Enemy may play Scissors”

Acceptance criteria:

* Magic Ball appears as a usable item.
* Clicking it consumes it.
* Prediction appears before player chooses a card.
* Prediction sometimes lies based on probability.

---

# Phase 7 — Card Effects Foundation

Do not hardcode every effect directly inside CardView.

Create simple effect system:

* Card has list of effect IDs.
* BattleResolver checks effect IDs during resolve.
* Effects can trigger on:

  * `on_win`
  * `on_lose`
  * `on_draw`
  * `on_play`
  * `on_turn_end`

Initial effects:

* Paper Cut:

  * On draw, deal 1 damage.
* Rock Guard:

  * Chance to negate incoming damage.
* Scissor Thrust:

  * Chance to deal +1 damage on win.

Acceptance criteria:

* At least 3 simple effects work.
* Effects are readable in card description.
* Effect triggers are shown visually with small text popups.

---

# Phase 8 — Enemy Pattern System

Enemy should not be fully random.

Create several enemy behaviors:

1. Random enemy:

   * chooses random card.
2. Repeater enemy:

   * tends to repeat the last winning card.
3. Counter enemy:

   * tends to counter the player’s previous card.
4. Biased enemy:

   * prefers one type, such as Rock-heavy.

Enemy card choice should be hidden until reveal.

Acceptance criteria:

* Enemy can use different selection patterns.
* Player can start reading the enemy’s behavior.
* Magic Ball becomes meaningful because enemy behavior is not pure random.

---

# Phase 9 — Reward and Upgrade Screen

After battle, show reward choices.

Reward types:

* Add new card.
* Upgrade existing card.
* Remove a card.
* Gain Magic Ball.
* Gain passive item.

For first version, implement only:

* Add upgraded card.
* Remove card.
* Gain Magic Ball.

Acceptance criteria:

* After winning battle, reward screen appears.
* Player can select one reward.
* Deck updates correctly.
* Next battle starts with updated deck.

---

# Phase 10 — UI Polish and Game Feel

Add juice:

* Card hover sound.
* Card select sound.
* Card slam sound.
* Damage sound.
* Small screen shake on hit.
* Floating damage numbers.
* Glow on active card.
* Pulse animation on usable item.
* Discard pile counter.
* Draw pile counter.

Balatro-like feel goals:

* Cards should feel physical.
* UI should be readable at a glance.
* Important numbers should pop.
* Animations should be fast but satisfying.
* Avoid overlong animations that slow the game.

Acceptance criteria:

* Selecting and playing cards feels satisfying.
* Player can understand game state without reading too much.
* UI has clear visual hierarchy.

---

# Phase 11 — Cleanup and Agent Rules

Implementation rules:

* Do not build all content at once.
* Finish one phase before moving to the next.
* Keep card data separate from card visuals.
* Keep battle logic separate from UI.
* Do not hardcode card paths inside many scripts.
* Use signals for UI events:

  * `card_hovered`
  * `card_unhovered`
  * `card_selected`
  * `card_play_requested`
  * `turn_resolved`
  * `battle_ended`

Final first-playable target:

* Player can play a full battle.
* Cards animate from hand to slot.
* Enemy reveals card.
* RPS resolves.
* HP updates.
* Magic Ball can predict enemy card.
* Reward screen appears after win.
