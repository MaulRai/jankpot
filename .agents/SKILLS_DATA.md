# Data Scripts Skills

Data scripts (`scripts/data/`) handle core game definitions and player state management.

## CardDef.gd

**Purpose:** Defines card data structure for weapon cards.

**Key Features:**
- Card types: ROCK, PAPER, SCISSORS
- Properties: id, name, brief description, art path, background color
- Keywords and effects system for card abilities
- Rarity and pricing system
- Skip and disabled card states

**Usage Example:**
```gdscript
var card: CardDef = CardDef.new()
card.card_type = CardDef.CardType.ROCK
card.keywords = ["Slashing", "Basic"]
var copy = card.copy()  # Deep copy
```

**Related Files:** `WeaponLibrary.gd`, `CardView.gd`

---

## EnemyDef.gd

**Purpose:** Defines enemy character data and combat properties.

**Key Properties:**
- Enemy name, display icon, description
- Health and stat definitions
- Deck composition
- Strategy configuration
- Rarity classification

**Integration:** Used by `EnemyCatalog.gd` for enemy pooling and `EnemyController.gd` for battle setup.

---

## WeaponLibrary.gd

**Purpose:** Central weapon card library and catalog system.

**Responsibilities:**
- Maintains list of all weapon cards
- Provides card lookup by ID
- Supports card filtering and search
- Integrates with resource file `WeaponLibrary.tres`

**Key Methods:**
- `get_card(id: String)` - Retrieve card definition
- `get_all_cards()` - Get complete card list
- `get_cards_by_rarity(rarity: String)` - Filter by rarity

---

## WeaponCatalog.gd

**Purpose:** Manages weapon availability and acquisition.

**Features:**
- Shop inventory management
- Card pool for drafting
- Rarity-weighted selection
- Disabled card filtering

**Used By:** `Shop.gd`, `PackOpening.gd`, reward systems

---

## EnemyCatalog.gd

**Purpose:** Enemy roster and battle pool management.

**Responsibilities:**
- Loads all enemy definitions
- Provides difficulty-based enemy selection
- Filters by stage or encounter type
- Supports boss/minion differentiation

**Integration:** `EnemyController.gd` queries this for opponent selection

---

## PlayerStorage.gd

**Purpose:** Persistent player progress and state management.

**Tracks:**
- Current run configuration
- Deck composition
- Consumable inventory (potions, items)
- Progress through stages
- Total stats and achievements

**Scope:** Game session state (not file-based persistence, but in-memory)

---

## RunConfig.gd

**Purpose:** Current run parameters and configuration.

**Contains:**
- Selected starting weapon
- Current stage number
- Money earned this run
- Deck modifications
- Environmental modifiers

**Usage:** Shared between `GameController.gd` and UI systems

---

## EffectKeyword.gd

**Purpose:** Weapon effect keyword definitions and descriptions.

**Features:**
- Keyword names and display text
- Tooltip descriptions
- Categorization (attack, defense, utility)
- Color coding system

**Integration:** Used by `TooltipManager.gd` for help display

---

## Tips for Data Scripts:

✓ Keep data definitions separate from logic
✓ Use enums for categorical fields (CardType, Rarity)
✓ Implement copy/duplicate for card variations
✓ Cache frequently accessed data
✓ Use `.tres` resource files for persistent definitions
