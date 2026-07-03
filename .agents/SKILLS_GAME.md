# Game Scripts Skills

Game scripts (`scripts/game/`) contain core battle logic, game flow, and decision-making systems.

## GameController.gd

**Purpose:** Main battle orchestrator and game state coordinator.

**Responsibilities:**
- Initializes battle with player and enemy
- Manages turn resolution
- Coordinates between sub-systems (DeckManager, BattleResolver, EnemyController)
- Tracks player/enemy HP
- Handles battle outcomes and rewards

**Key Signals:**
- `turn_resolved` - Emitted when a turn completes
- `battle_ended(winner: String)` - Battle conclusion
- `boss_victory(money_earned: int)` - Special boss victory signal

**Flow:**
1. Battle starts via scene transition
2. Player plays card from hand
3. Enemy selects card via strategy
4. Both cards resolved simultaneously
5. Effects applied, health updated
6. Rewards distributed on victory

**Related Systems:** `DeckManager`, `BattleResolver`, `EnemyController`

---

## DeckManager.gd

**Purpose:** Player deck management and card draw mechanics.

**Features:**
- Draw pile/discard pile management
- Shuffle mechanics
- Card drawing (with animation coordination)
- Deck modification (add/remove cards)
- Draw pile state visualization

**Key Methods:**
- `draw_card()` - Get next card from deck
- `add_card_to_deck(card: CardDef)`
- `shuffle_discard_into_draw_pile()`

**Integration:** Works with `HandView.gd` for visual display

---

## BattleResolver.gd

**Purpose:** Resolves card-vs-card outcomes and applies damage.

**Responsibilities:**
- Determines attack winner (Rock/Paper/Scissors logic)
- Calculates damage based on card effects
- Resolves special effects (keywords: Bleed, Shield, etc.)
- Returns battle resolution data

**Key Output:** `BattleEffectPlan` - structured resolution data passed to executor

**Process:**
1. Receive both cards
2. Determine base outcome (win/loss/draw)
3. Calculate damage modifiers from effects
4. Build effect plan
5. Return resolution

---

## BattleEffectResolver.gd

**Purpose:** Evaluates complex effect interactions and rule resolution.

**Handles:**
- Effect stacking (Bleed, Shield combination)
- Turn-based effect cleanup
- Keyword interactions
- Special conditions (consumables active, modifiers)

**Output:** Structured effect data consumed by `BattleEffectExecutor`

---

## BattleEffectExecutor.gd

**Purpose:** Applies resolved effects and updates game state.

**Actions:**
- Apply damage/healing
- Update status effects
- Modify temporary stats
- Queue animations
- Update UI

**Integration:** Coordinates with `BattleAnimator` for visual feedback

---

## BattleState.gd

**Purpose:** Immutable battle state container.

**Tracks:**
- Current player/enemy HP
- Active status effects
- Turn count
- Modifier list
- Draw pile state

**Usage:** Snapshot for undo/replay functionality

---

## BattleEffectPlan.gd

**Purpose:** Data structure representing resolved turn effects.

**Contains:**
- Base damage amounts
- Applied effects
- Status changes
- Animation instructions
- Effect descriptions

**Flow:** Created by `BattleResolver` → used by `BattleEffectExecutor`

---

## EnemyController.gd

**Purpose:** Enemy spawning, deck setup, and integration with AI strategy.

**Responsibilities:**
- Load enemy definition
- Initialize enemy deck
- Coordinate with strategy system
- Manage enemy-specific behaviors

**Related:** `EnemyStrategyContext.gd`, `EnemyStrategyEvaluator.gd`

---

## EnemyBattleDeck.gd

**Purpose:** Enemy-specific deck with weighted card selection.

**Features:**
- Weight-based card distribution
- Refresh mechanics
- Preference for specific cards against player strategies

**Integration:** Queried by `EnemyStrategyEvaluator` for card availability

---

## EnemyStrategyContext.gd

**Purpose:** Current evaluation context for enemy decision-making.

**Contains:**
- Player current card/stats
- Available enemy cards
- Health states
- Turn history
- Active effects

**Used By:** `EnemyStrategyEvaluator` for AI calculations

---

## EnemyStrategyEvaluator.gd

**Purpose:** AI decision-making system for enemy card selection.

**Algorithm:**
1. Evaluate all available cards
2. Score each against current game state
3. Consider win/loss probability
4. Apply risk/reward weighting
5. Return best card choice

**Configurable Via:** Enemy definition properties

---

## Game System Tips:

✓ Keep turn resolution atomic (single call = complete turn)
✓ Separate effect calculation from effect application
✓ Use data structures (Plans, Contexts) to pass complex state
✓ Emit signals for major state changes
✓ Cache player/enemy references for quick access
✓ Log important decisions for debugging strategy AI
