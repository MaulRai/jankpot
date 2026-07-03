# UI Scripts Skills

UI scripts (`scripts/ui/`) handle all visual interface elements and user interaction.

## BattleBoard.gd

**Purpose:** Central battle display showing health, status effects, and card slots.

**Displays:**
- Player/enemy heart counter (max health visual)
- Status effect icons (Bleed, Shield, Cup-a-Joe)
- Status pulses for effect activation
- Card slot backgrounds

**Key Methods:**
- `set_health(player_health, enemy_health)` - Update HP display
- `set_bleed_status(player_has_bleed, enemy_has_bleed)`
- `set_shield_status(player_shield, enemy_shield)` - Display shield values
- `set_cup_a_joe_status(active)`

**Features:**
- Heart animations for health changes
- Tween-based visual feedback
- Hover tooltips for status effects
- Custom status icons

**Integration:** Receives state updates from `GameController.gd`

---

## CardView.gd

**Purpose:** Renders individual card with art, name, effects, and keywords.

**Displays:**
- Card artwork and background
- Card name and type icon
- Effect keyword list with icons
- Brief description text
- Rarity indicator
- Current card stats (if applicable)

**Features:**
- Dynamic layout for variable keyword counts
- Tooltip integration for detailed descriptions
- Hover effects and scale animations
- Disabled state visual (grayed out)

**Used By:** Hand, card slots, preview areas, reward overlay

---

## CardSlot.gd

**Purpose:** Interactive card placement area for player and enemy selections.

**Responsibilities:**
- Display selected card (or empty state)
- Handle card reveal animations
- Show card comparison during reveal
- Manage slot state (ready, locked, disabled)

**Signals:**
- `card_selected(card: CardDef)` - Player interaction
- `animation_finished` - Reveal animation complete

**States:**
- Empty (waiting for selection)
- Selected (card chosen)
- Locked (can't change)
- Animating (reveal in progress)

---

## HandView.gd

**Purpose:** Display and manage player hand of available cards.

**Features:**
- Dynamic card arrangement based on hand size
- Card selection interaction
- Hand shuffling animation
- Empty hand state
- Maximum card limit visual feedback

**Integration:** Communicates selected cards to `GameController.gd`

---

## BattleSidebar.gd

**Purpose:** Side panel showing battle info, turn counter, and status.

**Displays:**
- Current stage/enemy name
- Turn counter
- Money earned this run
- Consumable quick access
- Game status messages

**Dynamic Updates:**
- Stage progression
- Enemy defeat milestones
- Money gain/loss feedback

---

## DiscardViewer.gd

**Purpose:** Modal window showing discarded cards this turn.

**Features:**
- Scrollable card list
- Card tooltips on hover
- Discard count summary
- Close button interaction

**Triggers:** After player action when discard pile modified

---

## DrawPileViewer.gd

**Purpose:** Displays remaining cards in draw pile (stack preview).

**Shows:**
- Top 3 cards of draw pile (stacked visual)
- Remaining card count
- Shuffle indicator

**Real-time Updates:** Reflects actual draw pile state

---

## MagicBallModal.gd

**Purpose:** Special modal for Magic Ball consumable effect (peak at next card).

**Features:**
- Shows upcoming card from draw pile
- Animated reveal
- Card preview with full details
- Confirmation button

**Integration:** Triggered by consumable usage in `ConsumableShelf.gd`

---

## ConsumableShelf.gd

**Purpose:** Display and manage consumable items (potions, special items).

**Features:**
- Show available consumables with count
- Item activation on click
- Item effect triggers
- Disabled state (empty/used)

**Items Supported:**
- Health potions
- Shield items
- Special effect items

**Integration:** Updates from `GameController` or inventory system

---

## RewardOverlay.gd

**Purpose:** Modal window for battle reward selection.

**Features:**
- Display 3-5 reward options
- Card preview on hover
- Selection interaction
- Confirmation animations

**Reward Types:**
- New weapon cards
- Consumable items
- Modifier items
- Money bonuses

---

## TooltipManager.gd

**Purpose:** Centralized tooltip/help system for all game elements.

**Features:**
- Dynamic tooltip positioning
- Keyword descriptions
- Card effect explanations
- Status effect clarifications
- Auto-hide on scroll/movement

**Integration:** Referenced by many UI elements for hover support

---

## TooltipBox.gd

**Purpose:** Rendered tooltip display component.

**Features:**
- Text rendering with formatting
- Background panel with borders
- Icon display support
- Position adjustment for screen edges

**Styling:** Uses game theme system

---

## PixelFramePanel.gd

**Purpose:** Decorative pixel art frame for UI windows, cards, and buttons.

**Features:**
- Corner and edge rendering
- Customizable size
- Integrated shading
- Nested panel support
- **Shining variation** - Corner shining effect in top right corner (configurable)

**Usage:**
- Card backgrounds and borders
- Button styling and frames
- Window/modal frames
- Decorative panel elements

**Available Assets:**
- `assets/ui/component/corner.png` - Standard corner
- `assets/ui/component/corner-shining.png` - Shining corner variant (top right)
- `assets/ui/component/side.png` - Edge/side element
- `assets/ui/component/base.png` - Base background panel

**Example Configurations:**
```gdscript
# Card with standard frame
var card_frame = PixelFramePanel.new()
card_frame.size = Vector2(150, 200)

# Button with shining corner
var button_frame = PixelFramePanel.new()
button_frame.size = Vector2(120, 50)
button_frame.use_shining_corner = true
```

---

## PauseOverlay.gd

**Purpose:** Game pause menu overlay.

**Options:**
- Resume game
- View deck
- View settings
- Return to main menu
- Quit game

**Functionality:**
- Pauses game loop
- Darkens background
- Shows menu buttons
- Keyboard shortcuts

---

---

## UI Rendering & Styling

### Default Font
- **Font File:** `fonts/Star Crush.ttf` or `fonts/Star Crush.otf`
- **Applied Via:** `themes/game_theme.tres` (project-wide theme)
- **Variants:** Both TTF and OTF formats available
- **License:** See `fonts/1001fonts-star-crush-eula.txt`

### Theme System
- **Master Theme:** `themes/game_theme.tres`
- Centralized styling for all UI elements
- Font, colors, and sizes defined once
- Apply to any Control node via `theme` property

### Available UI Components for Immediate Use

**For Cards & Buttons:**
- ✓ `PixelFramePanel.gd` - Pixel art borders with optional shining corner
- ✓ `CardView.gd` - Renders complete card visuals
- ✓ Built-in corner shining effect in top right (from component assets)

**For Modals & Overlays:**
- ✓ `PauseOverlay.gd` - Complete pause menu implementation
- ✓ `RewardOverlay.gd` - Reward selection screen
- ✓ `MagicBallModal.gd` - Special effect modals

**For Information Display:**
- ✓ `TooltipBox.gd` - Styled tooltip rendering
- ✓ `BattleSidebar.gd` - Status panel
- ✓ All use consistent theme system

### Quick Styling Tips

```gdscript
# Use existing theme on new UI elements
var my_panel = Panel.new()
my_panel.theme = load("res://themes/game_theme.tres")

# Apply PixelFramePanel to any control
var framed_element = PixelFramePanel.new()
framed_element.add_child(my_content)
```

---

## UI Best Practices:

✓ Use PixelFramePanel for cards, buttons, and frames
✓ Apply game_theme.tres to maintain consistent styling
✓ Use "Star Crush" font from themes/game_theme.tres
✓ Keep visual updates responsive (< 1 frame delay)
✓ Use signals for component communication
✓ Cache frequently accessed nodes with @onready
✓ Implement hover states for interactivity feedback
✓ Use tweens for smooth animations
✓ Test tooltip positioning on different screen sizes
✓ Group related UI elements in scenes
✓ Leverage shining corner effect for visual hierarchy
