# Animation Scripts Skills

Animation scripts (`scripts/animation/`) manage visual effects, tweens, and combat animations.

## BattleAnimator.gd

**Purpose:** Orchestrates all combat animations (card reveal, attacks, effects, etc.).

**Responsibilities:**
- Coordinate card reveal animations
- Play attack impact animations
- Animate status effect application
- Sync animations with effect resolution
- Handle animation sequencing and timing

**Key Methods:**
- `animate_card_reveal(card_slot_a, card_slot_b)` - Reveal both cards
- `animate_damage(target, amount, effect_type)` - Show damage numbers/impact
- `animate_effect_apply(effect_name, target)` - Show effect visuals
- `wait_for_animation()` - Async animation completion

**Features:**
- Tween-based smooth animations
- Particle effect support
- Screen shake on impact
- Color flash effects
- Scale/rotation effects

**Integration:**
- Triggered by `GameController.gd` or `BattleEffectExecutor.gd`
- Coordinates with `SFXManager.gd` for sound sync
- Updates UI via signal callbacks

**Timing:**
- Most animations 0.3-0.8 seconds
- Can be skipped/fast-forwarded by player
- Animations queue automatically

**Configuration:**
```gdscript
# Export properties for tuning
@export var card_flip_duration := 0.4
@export var damage_pop_duration := 0.6
@export var shake_intensity := 10.0
```

---

## CardExitAnimator.gd

**Purpose:** Animates cards leaving the game (discard, defeat).

**Features:**
- Card fly-out animation to discard pile
- Rotation and scale effects
- Fade out option
- Direction-based movement

**Used When:**
- Card is played (moves to discard)
- Card is removed from hand
- Battle ends (card removal)

**Behavior:**
```gdscript
# Example animation path:
# Original position → Discard pile position
# Rotation: 0° → 180°
# Scale: 1.0 → 0.8
# Duration: 0.3-0.5s
```

**Integration:**
- Called by hand management system
- Coordinates with sound effects
- Signals completion to DeckManager

---

## Animation Patterns Used:

### Tweens
- **Movement:** Tween.tween_property(position)
- **Scaling:** Tween.tween_property(scale)
- **Rotation:** Tween.tween_property(rotation)
- **Transparency:** Tween.tween_property(modulate.a)
- **Color:** Tween.tween_property(modulate)

### Common Animation Properties:
```gdscript
# Ease and transition types
.set_trans(Tween.TRANS_SINE)      # Smooth curve
.set_trans(Tween.TRANS_BACK)      # Overshoot effect
.set_trans(Tween.TRANS_ELASTIC)   # Bounce effect
.set_ease(Tween.EASE_OUT)         # Decelerate
.set_ease(Tween.EASE_IN)          # Accelerate
```

### Animation Timing:
- Quick feedback: 0.1-0.2s
- Standard animation: 0.3-0.5s
- Emphasis animation: 0.6-0.8s
- Long transitions: 1.0-2.0s

---

## Effect Animation Examples:

**Damage Display:**
```
Trigger: Enemy takes damage
├─ Flash red (0.1s)
├─ Shake (0.2s)
├─ Number popup + fade out (0.6s)
└─ Sound effect (hit.mp3)
```

**Status Effect Application:**
```
Trigger: Bleed applied
├─ Status icon appears
├─ Icon pulse animation
├─ Brief shake
└─ Sound cue (effect-apply.mp3)
```

**Card Reveal:**
```
Trigger: Turn begins
├─ Both cards flip simultaneously
├─ Slight scale-up
├─ Landing effect
└─ Sound effect (card-reveal.mp3)
```

---

## Animation Best Practices:

✓ Keep animations under 1 second (except special cases)
✓ Use tweens instead of frame-based AnimationPlayer for simplicity
✓ Make animations skippable in fast mode
✓ Cache and reuse tween patterns
✓ Match animation timing with audio cues
✓ Avoid simultaneous animations on same property (causes conflicts)
✓ Use visual feedback for all player actions
✓ Test animation performance on low-end devices
✓ Consider colorblind players (don't rely on color alone)

---

## Adding New Animations:

1. **Identify trigger event** (when should animation start)
2. **Design visual effect** (what should player see)
3. **Determine duration** (how long should it take)
4. **Match audio** (what sound plays)
5. **Implement tween** (code animation)
6. **Test frame rate** (ensure smooth 60 FPS)
7. **Make optional** (allow skipping in fast mode)

**Example Implementation:**
```gdscript
func animate_custom_effect(target: Node2D, duration: float) -> void:
	var tween = create_tween()
	tween.set_parallel(true)  # All animations together
	tween.tween_property(target, "modulate:v", 1.5, duration / 2)
	tween.tween_property(target, "scale", Vector2(1.2, 1.2), duration / 2)
	tween.tween_callback(lambda: sfx_manager.play_sfx("effect"))
```
