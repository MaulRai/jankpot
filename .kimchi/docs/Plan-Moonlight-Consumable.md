# Moonlight Consumable + Card Picking Mode

## Summary

Implement a new consumable item **Moonlight** ($2) that lets the player **discard up to 2 cards from hand, then draw the same number**. This requires building a reusable **card picking mode** where the player selects N cards from hand and clicks a "Choose" button to confirm the action.

## Changes Required

### 1. Moonlight Consumable (Game data + UI)

- **Texture:** `res://assets/item/moonlight.png` (already exists)
- **Price:** $2 (stored in PlayerStorage)
- **Keyword:** Add `"Moonlight"` keyword to EffectKeyword for colored tooltip
- **ConsumableShelf.gd:** Add `add_moonlight()` and `consume_moonlight()` following existing pattern
- **PlayerStorage.gd:** Add `CONSUMABLE_MOONLIGHT := "moonlight"` constant
- **GameController.gd:** Wire up `consumable_shelf.moonlight_requested` signal

### 2. Card Picking Mode (Reusable UI)

- **New script: `PickMode.gd`** — A reusable overlay/modal that:
  - Takes a list of cards (Array[CardDef])
  - Lets the player pick N cards (configurable min/max)
  - Shows a "Choose" button on enter (hidden otherwise)
  - Selected cards show more lifted (raised position, slight scale)
  - Calls a callback with the selected cards when "Choose" is clicked
  - Cleanly closes/cleans up

- **Integration:**
  - HandView needs a method to enter "pick mode" (disable drag, mark selected cards with raised/lifted visual)
  - Moonlight uses PickMode to: show hand, let player pick up to 2 cards, then discard those and draw same amount

### 3. Trigger flow

1. Player clicks Moonlight on shelf
2. GameController enters pick mode: `pick_mode.start(hand_cards, max_pick=2, on_choose_callback)`
3. Player picks cards (visually lifted)
4. Player clicks "Choose"
5. GameController discards selected cards, draws same number
6. Moonlight consumed

## Files to Modify/Create

- **CREATE:** `scripts/ui/PickMode.gd` — the reusable picking overlay
- **CREATE:** `scenes/ui/PickMode.tscn` — scene for the overlay
- **MODIFY:** `scripts/ui/ConsumableShelf.gd` — add moonlight entry
- **MODIFY:** `scripts/ui/HandView.gd` — add `enter_pick_mode`/`exit_pick_mode` methods
- **MODIFY:** `scripts/ui/CardView.gd` — add `set_selected_visual` support
- **MODIFY:** `scripts/game/GameController.gd` — wire moonlight
- **MODIFY:** `scripts/data/PlayerStorage.gd` — add moonlight constant
- **MODIFY:** `scripts/data/EffectKeyword.gd` — add "Moonlight" color & description