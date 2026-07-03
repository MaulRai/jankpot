# Audio Scripts Skills

Audio scripts (`scripts/audio/`) manage music and sound effects throughout the game.

## BGMPlayer.gd

**Purpose:** Background music management with fade transitions.

**Features:**
- Auto-loop music (WAV/MP3 detection)
- Fade-in on start (customizable duration)
- Fade-out on transition
- Volume normalization (-6dB max)
- Master bus mute handling

**Exports:**
- `fade_in_duration` (0.0-10.0 seconds, default 2.0)

**Setup:**
1. Attach to AudioStreamPlayer node
2. Assign music file (WAV or MP3)
3. Parent BGMPlayer handles fade_in on ready

**Audio Bus:** Routed through "Master" bus

**Usage Example:**
```gdscript
# In scene with BGMPlayer
var bgm = $BGMPlayer
# Music auto-plays with fade-in
# To change music:
bgm.stream = load("res://audio/bgm/shop-loop.mp3")
bgm.play()
```

**Best Practices:**
- Export music at -6dB to -12dB (avoid clipping)
- Use seamless loops (professional tools: FMOD, wwise, or Audacity)
- Loop point metadata in WAV header (if supported)

---

## SFXManager.gd

**Purpose:** Sound effect playback system with pooling and volume control.

**Responsibilities:**
- Queue and play SFX without cutoff
- Volume normalization for consistency
- Priority-based playback (important > ambient)
- Spatial audio support (optional)
- Effect cleanup

**Key Methods:**
- `play_sfx(effect_name: String)` - Play sound by name
- `play_sfx_at(effect_name: String, position: Vector2)` - Spatial audio
- `stop_all_sfx()` - Clear active effects
- `set_sfx_volume(db: float)` - Adjust SFX level

**Features:**
- Sound pooling to prevent CPU overhead
- Fallback for missing sounds
- Volume ducking (optional)
- Category-based volume control

**Audio Bus:** "SFX" bus for independent volume control

**Integration Points:**
- Called by game events (card play, damage, etc.)
- Animation system triggers SFX
- UI interactions play feedback sounds

**Sound Categories:**
- `ui/` - Interface clicks and selections
- `effects/` - Gameplay impact sounds
- `music/` - Musical cues
- `dialogue/` - Character sounds

---

## Audio Architecture:

**Bus Hierarchy:**
```
Master (main output)
├── BGM (background music)
├── SFX (sound effects)
│   ├── UI
│   ├── Combat
│   └── Ambient
└── Voice (character sounds)
```

**File Organization:**
- `audio/bgm/` - Background music tracks
- `audio/sfx/` - Sound effects by category
- `audio/blip/` - Character sounds and voices

---

## Common Audio Tasks:

**Playing Music:**
```gdscript
# Auto-handles fade-in through BGMPlayer
get_node("BGMPlayer").stream = preload("res://audio/bgm/battle-loop.mp3")
```

**Playing Sound Effects:**
```gdscript
# From anywhere in game
sfx_manager.play_sfx("hit")
sfx_manager.play_sfx("card-pickup")
sfx_manager.play_sfx_at("explosion", enemy_position)
```

**Volume Control:**
```gdscript
# Master volume
AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -10.0)
```

---

## Audio Tips:

✓ Use compressed formats (MP3, OGG) for large music files
✓ Use uncompressed formats (WAV) for short SFX (< 1 second)
✓ Normalize all audio to -6dB to -3dB (prevent clipping)
✓ Use buses for easy volume control per category
✓ Test audio on different speaker setups
✓ Implement audio settings menu for player control
✓ Use spatial audio sparingly (CPU intensive)
✓ Cache frequently used SFX (avoid disk reads mid-gameplay)
