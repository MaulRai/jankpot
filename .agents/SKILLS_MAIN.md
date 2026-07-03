# Main Scripts Skills

Main scripts (`scripts/main/`) control scene flow, transitions, and progression between game states.

## MainMenu.gd

**Purpose:** Main menu scene controller and game entry point.

**Features:**
- Start new game button
- Continue run option (if in progress)
- Settings/options access
- Credits/help display
- Quit game

**Flow:**
1. Display menu with options
2. Handle player selection
3. Initialize run config on new game
4. Transition to next scene

**Signals Emitted:**
- `start_new_game()` - Trigger game init
- `continue_game()` - Resume saved run
- `open_settings()`

**Integration:**
- Loads BGM (main-menu-loop)
- Checks for saved run data
- Initializes PlayerStorage if needed

---

## Preparation.gd

**Purpose:** Pre-battle setup and deck review scene.

**Responsibilities:**
- Display current deck composition
- Show equipped items/consumables
- Allow deck modifications (if allowed)
- Show upcoming enemy preview
- Handle transition to battle

**Flow:**
1. Load player deck from storage
2. Display all cards
3. Show consumable inventory
4. Show stage/enemy info
5. Battle transition

**Deck Display:**
- Card count by type
- Total stats summary
- Discard pile preview
- Card filtering/sorting

**Features:**
- Scroll through entire deck
- View card details on hover
- Equipment screen
- Quick start to battle

---

## Shop.gd

**Purpose:** Shop scene for card acquisition and upgrades.

**Responsibilities:**
- Display available cards for purchase
- Handle card selection and purchase
- Display player money
- Generate random shop stock
- Handle transaction logic

**Flow:**
1. Generate shop inventory (random or weighted)
2. Display cards with prices
3. Player selects and buys cards
4. Update inventory and money
5. Progress to next stage or results

**Shop Types:**
- Weapon shop (main shop)
- Equipment shop (consumables)
- Upgrade shop (modify existing cards)

**Features:**
- Card rarity-based pricing
- Limited stock per visit
- Refresh shop option (costs money)
- Card recommendations

**Integration:**
- Uses `WeaponCatalog.gd` for card pool
- Updates `PlayerStorage.gd` inventory
- Manages money transactions

---

## PackOpening.gd

**Purpose:** Animated card pack opening sequence.

**Features:**
- Card reveal animations
- Rarity-based visual effects
- Particle effects for rare cards
- Sound effects per rarity
- Card selection/confirmation

**Flow:**
1. Show pack graphic
2. Animate pack opening
3. Reveal cards one by one
4. Highlight rarity
5. Allow card selection
6. Add to deck

**Rarity Effects:**
- Common: Standard reveal
- Uncommon: Glow effect
- Rare: Particles + sound fanfare
- Legendary: Special animation + music

---

## GameplayIntro.gd

**Purpose:** Introduction scene before first battle.

**Features:**
- Show stage number and enemy
- Display stage description/narrative
- Enemy introduction animation
- Background setup
- Transition to battle

**Narrative Integration:**
- Academy stage progression
- Enemy background information
- Difficulty scaling feedback

---

## CardRevealFx.gd

**Purpose:** Special visual effect for card reveals in packs/rewards.

**Features:**
- Card flip animation
- Light/particle effects
- Timing synchronization
- Optional character voice

**Used In:**
- Pack opening
- Reward selection
- Card discovery moments

---

## Scene Progression Flow:

```
MainMenu
    ↓ (New Game)
Preparation (First Time)
    ↓ (Start)
GameplayIntro (Stage 1)
    ↓
BattleBoard (Combat)
    ↓ (Victory)
Shop (Purchase Cards)
    ↓ (Continue)
Preparation (Next Stage)
    ↓
GameplayIntro
    ↓
BattleBoard (Combat)
    ... (repeat)
    ↓ (Final Victory)
Results Screen
    ↓
MainMenu (New Cycle)
```

---

## Main System Tips:

✓ Use `get_tree().change_scene_to_file()` for scene transitions
✓ Emit signals for scene readiness (don't hard-code dependencies)
✓ Save progress before transitions (crash recovery)
✓ Preload heavy resources in background
✓ Handle pause state in transitions
✓ Fade in/out between scenes
✓ Load scene metadata from resource files
✓ Support skip/fast-forward for repeated sequences

---

## State Management Between Scenes:

**PlayerStorage.gd** persists:
- Deck composition
- Current money
- Current consumables
- Progress stage
- Run history

**RunConfig.gd** holds:
- Current stage number
- Selected weapon
- Environmental modifiers
- Run duration

**Access Pattern:**
```gdscript
var storage = PlayerStorage.instance()
var run_config = RunConfig.instance()
var current_deck = storage.get_deck()
var stage = run_config.current_stage
```

---

## Transition Best Practices:

✓ Fade to black before loading heavy scene
✓ Show loading indicator for long transitions
✓ Preload assets while showing intro scene
✓ Disable input during scene changes
✓ Save state before critical transitions
✓ Show stage/enemy info during loading
✓ Smooth fade-in after load complete
