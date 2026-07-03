# Jank Pot - Script Skills Documentation

Complete reference guide for all Godot scripts in the Jank Pot card battle game.

## Overview

This project is organized into **6 skill categories**, each documented separately:

| Skill | Purpose | Key Scripts |
|-------|---------|-------------|
| **[Data](SKILLS_DATA.md)** | Game definitions and player state | CardDef, EnemyDef, PlayerStorage, Catalogs |
| **[Game](SKILLS_GAME.md)** | Battle logic and AI systems | GameController, BattleResolver, EnemyStrategy |
| **[UI](SKILLS_UI.md)** | Visual interface elements | BattleBoard, CardView, HandView, Overlays |
| **[Audio](SKILLS_AUDIO.md)** | Music and sound effects | BGMPlayer, SFXManager, audio buses |
| **[Animation](SKILLS_ANIMATION.md)** | Visual effects and tweens | BattleAnimator, CardExitAnimator |
| **[Main](SKILLS_MAIN.md)** | Scene flow and progression | MainMenu, Shop, Preparation, GameplayIntro |

---

## Architecture Overview

### System Layer Dependencies:

```
┌─────────────────────────────────────────┐
│           UI Layer                      │
│  (CardView, BattleBoard, HandView)      │
└────────────────┬────────────────────────┘
                 │ updates/queries
┌────────────────▼────────────────────────┐
│       Game Logic Layer                  │
│  (GameController, BattleResolver)       │
└────────────────┬────────────────────────┘
                 │ loads/modifies
┌────────────────▼────────────────────────┐
│       Data Layer                        │
│  (CardDef, EnemyDef, PlayerStorage)     │
└─────────────────────────────────────────┘
```

### Signal Flow:

```
Player Action (hand click)
    ↓
HandView signals card selection
    ↓
GameController._on_card_selected()
    ↓
BattleResolver.resolve()
    ↓
BattleAnimator.animate_*()
    ↓
SFXManager.play_sfx()
    ↓
UI updates (BattleBoard.set_health, etc.)
```

---

## Quick Reference by Task

### "How do I..."

**Add a new card type?**
→ See [CardDef](SKILLS_DATA.md#carddefgd), [WeaponLibrary](SKILLS_DATA.md#weaponlibrarygd)

**Change battle rules?**
→ See [BattleResolver](SKILLS_GAME.md#battleresolvergd), [BattleEffectResolver](SKILLS_GAME.md#battleeffectresolvergd)

**Improve enemy AI?**
→ See [EnemyStrategyEvaluator](SKILLS_GAME.md#enemystrategyevaluatorgd)

**Update UI display?**
→ See [BattleBoard](SKILLS_UI.md#battleboardgd), [CardView](SKILLS_UI.md#cardviewgd)

**Add sound effects?**
→ See [SFXManager](SKILLS_AUDIO.md#sfxmanagergd), [BGMPlayer](SKILLS_AUDIO.md#bgmplayergd)

**Create animations?**
→ See [BattleAnimator](SKILLS_ANIMATION.md#battleanimatorgd), Animation Patterns

**Modify game flow?**
→ See [MainMenu](SKILLS_MAIN.md#mainmenugd), Scene Progression Flow

**Store player data?**
→ See [PlayerStorage](SKILLS_DATA.md#playerstoragegd), [RunConfig](SKILLS_DATA.md#runconfiggd)

---

## Script Directory Structure

```
scripts/
├── data/              [→ SKILLS_DATA.md]
│   ├── CardDef.gd
│   ├── EnemyDef.gd
│   ├── WeaponLibrary.gd
│   ├── WeaponCatalog.gd
│   ├── EnemyCatalog.gd
│   ├── PlayerStorage.gd
│   ├── RunConfig.gd
│   └── EffectKeyword.gd
│
├── game/              [→ SKILLS_GAME.md]
│   ├── GameController.gd
│   ├── DeckManager.gd
│   ├── BattleResolver.gd
│   ├── EnemyController.gd
│   ├── battle/
│   │   ├── BattleState.gd
│   │   ├── BattleEffectPlan.gd
│   │   ├── BattleEffectResolver.gd
│   │   └── BattleEffectExecutor.gd
│   └── enemy/
│       ├── EnemyBattleDeck.gd
│       ├── EnemyStrategyContext.gd
│       └── EnemyStrategyEvaluator.gd
│
├── ui/                [→ SKILLS_UI.md]
│   ├── BattleBoard.gd
│   ├── CardView.gd
│   ├── CardSlot.gd
│   ├── HandView.gd
│   ├── BattleSidebar.gd
│   ├── DiscardViewer.gd
│   ├── DrawPileViewer.gd
│   ├── MagicBallModal.gd
│   ├── ConsumableShelf.gd
│   ├── RewardOverlay.gd
│   ├── PauseOverlay.gd
│   ├── TooltipManager.gd
│   ├── TooltipBox.gd
│   └── PixelFramePanel.gd
│
├── audio/             [→ SKILLS_AUDIO.md]
│   ├── BGMPlayer.gd
│   └── SFXManager.gd
│
├── animation/         [→ SKILLS_ANIMATION.md]
│   ├── BattleAnimator.gd
│   └── CardExitAnimator.gd
│
└── main/              [→ SKILLS_MAIN.md]
    ├── MainMenu.gd
    ├── Preparation.gd
    ├── Shop.gd
    ├── GameplayIntro.gd
    ├── CardRevealFx.gd
    └── PackOpening.gd
```

---

## Key Concepts

### Card System
- **CardDef:** Individual card data (type, effects, rarity)
- **WeaponLibrary:** All available cards
- **CardView:** Renders a card visually
- **DeckManager:** Player deck operations

### Battle System
- **GameController:** Main battle orchestrator
- **BattleResolver:** Determines battle outcome (RPS logic)
- **BattleEffectResolver:** Complex effect interactions
- **BattleState:** Current turn state snapshot

### AI System
- **EnemyController:** Enemy setup and control
- **EnemyStrategyContext:** Current decision context
- **EnemyStrategyEvaluator:** AI decision algorithm

### UI System
- **BattleBoard:** Health and status display
- **HandView:** Player card hand
- **CardSlot:** Individual card slot
- **Overlay:** Modals (rewards, pause, etc.)

### Data System
- **PlayerStorage:** Session progress
- **RunConfig:** Current run parameters
- **Catalogs:** Card/enemy pools

---

## Common Workflows

### Adding a New Card:
1. Create **CardDef** resource in `resources/weapons/`
2. Add to **WeaponLibrary.tres**
3. Create artwork in `assets/weapon/`
4. Test in **Shop** scene

### Implementing New Effect:
1. Add keyword to **EffectKeyword.gd**
2. Update **BattleResolver** logic
3. Add animation in **BattleAnimator**
4. Add sound in **SFXManager**
5. Test in battle

### Creating New Scene:
1. Design in editor (scenes/)
2. Attach script (scripts/main/ or scripts/ui/)
3. Add signals for transitions
4. Emit from **MainMenu** or **GameController**
5. Handle cleanup on scene exit

---

## Performance Tips

- Cache preloaded resources
- Pool animations (reuse tweens)
- Limit simultaneous animations
- Use object pooling for cards
- Batch UI updates
- Limit tooltip updates to hover events
- Profile in release mode

---

## Testing & Debugging

### Test Scenarios:
- Deck with all same card type
- Consumable combinations
- Status effect stacking
- AI vs different strategies
- UI at different resolutions

### Debug Tools:
- Print battle state after each turn
- Log enemy AI decisions
- Visualize effect queue
- Test animation timing

---

## Related Documentation

- [README.md](README.md) - Project overview
- [IMPLEMENTATION.md](IMPLEMENTATION.md) - Implementation details
- [enemy-mode.md](markdown/enemy-mode.md) - Enemy system specifics

---

**Last Updated:** 2026-07-03  
**Project:** Jank Pot (Godot 4.x)  
**Version:** See project.godot for version info
