extends Control

const WeaponCatalogData = preload("res://scripts/data/WeaponCatalog.gd")
const PackOpeningScript := preload("res://scripts/main/PackOpening.gd")
const PlayerStorageData = preload("res://scripts/data/PlayerStorage.gd")

const MAIN_MENU_SCENE_PATH := "res://scenes/main/MainMenu.tscn"
const RESET_SECONDS        := 60 * 60 * 3
const HOVER_SCALE          := Vector2(1.06, 1.06)
const PRESS_SCALE          := Vector2(0.95, 0.95)
const SHOPKEEPER_TYPE_INTERVAL := 0.018
const SHOPKEEPER_THANKS_HOLD_RANGE := Vector2(6.0, 8.0)
const SHOPKEEPER_BLIP_MIN_INTERVAL := 0.095
const SHOPKEEPER_BLIP_STREAM := preload("res://audio/blip/shopkeeper-neutral.mp3")

const STAR_CRUSH_FONT    := preload("res://fonts/Star Crush.otf")
const BASIC_PACK_TEXTURE := preload("res://assets/item/pack/basic-weapon-card-pack.png")
const PREMIUM_PACK_TEXTURE := preload("res://assets/item/pack/premium-weapon-card-pack.png")
const SHOP_DISPLAY_TEXTURE := preload("res://assets/ui/shop-display.png")
const MAGIC_BALL_TEXTURE := preload("res://assets/item/magic-ball.png")
const SHIELD_TEXTURE     := preload("res://assets/item/shield.png")
const REMEDY_KIT_TEXTURE := preload("res://assets/item/remedy-kit.png")
const CUP_A_JOE_TEXTURE  := preload("res://assets/item/cup-a-joe.png")
const SNAKE_OIL_TEXTURE  := preload("res://assets/item/snake-oil.png")
const POCKETWATCH_TEXTURE := preload("res://assets/item/pocketwatch.png")
const VELVET_GLOVES_TEXTURE := preload("res://assets/item/velvet-gloves.png")
const L_IVOIRE_TEXTURE := preload("res://assets/item/l-ivoire.png")
const SEALED_MISSIVE_TEXTURE := preload("res://assets/item/sealed-missive.png")
const CURIO_TEXTURE := preload("res://assets/item/curio.png")

const SHOPKEEPER_LINES := [
	"Welcome back. The shelves have been whispering about you.",
	"Step softly. Some of these goods dislike desperate hands.",
	"Coin first, confidence later.",
	"Every duel leaves a mark. I sell ways to hide the scar.",
	"Take your time. Bad decisions are cheaper when made slowly.",
	"The table outside asks questions. I sell possible answers.",
	"Nothing here is cursed. Not officially.",
	"Browse carefully. Some tools are more honest than their owners.",
	"Everything is discounted emotionally, not financially.",
	"I polished the Shield. It still blocks better than most plans.",
	"The Magic Ball says you will buy something. Suspicious, yes?",
	"Remedy Kits are for people who said, 'I'll be fine.'",
	"Cup-a-Joe: for when strategy needs caffeine.",
	"If it breaks, it was probably rare.",
	"Do not lick the Ruby. Again, not a suggestion.",
	"The Hatter Slip moved itself to the front shelf. I did not ask why.",
	"A Shield can save a clash. A Magic Ball can save a guess.",
	"If ailments are eating your hearts, Remedy Kit is cheaper than regret.",
	"Do not trust luck. Improve it.",
	"Quartz is simple: lose less, live longer.",
	"Bronze Razor likes chance. Hatter Slip likes chance even more.",
	"Sculptural Sheet turns a draw into a warning.",
	"Rusty Shears is quiet until the wound starts counting.",
	"Mist Veil is not about winning harder. It is about giving the enemy fewer answers.",
	"Guillotine Blades end fights quickly. Sometimes yours.",
	"Ruby does not prevent mistakes. It gives one of them back.",
	"Spike Boulder rewards enemies who forget rocks can bite.",
	"Cards in hand are not idle. Some are waiting.",
	"Information is also damage, if used at the right time.",
	"Magic Ball today? It predicts futures. Not refunds.",
	"Shield is plain, reliable, and rarely dramatic. A rare quality.",
	"Remedy Kit removes Bleed and Poison. It does not remove embarrassment.",
	"Cup-a-Joe makes a winning attack strike twice. Drink before courage expires.",
	"Looking for a random card? The sealed ones are shy.",
	"Some weapons win clashes. Some weapons survive them.",
	"Common cards are not weak. They are honest.",
	"Rare cards are powerful because they make worse mistakes possible.",
	"Pour some Snake Oil if you want them to slowly wither. It bites twice as hard if you've been losing.",
	"This Snake Oil cures nothing, but it makes the enemy's blood turn toxic. Do not drink.",
	"Keep this Pocketwatch close. It catches your stumbles and spins them into an Aegis.",
	"This Pocketwatch won't tell the time, but losing a clash will trigger an Aegis. How timely.",
	"Slip on the Velvet Gloves and pull exactly what you need. No one has to know it wasn't luck.",
	"Velvet Gloves: for handling your deck with maximum bias. Very elegant cheating.",
	"L'Ivoire is a delicate thing. It calls a rare set of blades to your deck.",
	"That ivory token L'Ivoire will drop a rare pair of scissors from thin air. Watch your fingers.",
	"Break the wax on this Sealed Missive. It binds a rare parchment to your hand for the entire run.",
	"A Sealed Missive. Once opened, a rare piece of paper joins your deck. Deadlier than bills.",
	"This Curio is heavy with old magic. It leaves a rare stone for your entire run.",
	"This Curio binds a rare stone to your deck. A very expensive pet rock.",
	"Garnet holds strong under pressure, raising an Aegis to guard you when your health hits rock bottom.",
	"That Garnet stone looks shiny, but it only starts acting like a shield when you're about to meet your maker.",
	"Origami is a highly adaptable parchment. It folds into whichever shape beats the opponent's choice, if one exists.",
	"Origami: looks like plain paper, but folds under pressure. In a good way.",
]

const SHOPKEEPER_THANKS_LINES := [
	"Thanks. May it behave better for you than it did for the last owner.",
	"Thanks. A clean deal is a rare little comfort.",
	"Thank you. Spend it wisely, or at least memorably.",
	"Thanks. The shelf looks less crowded already.",
]

@onready var _offers_grid:  GridContainer  = %OffersGrid
@onready var _reset_label:  Label          = %ResetLabel
@onready var _back_button:  Button         = %BackButton
@onready var _back_frame:   PixelFramePanel = %BackFrame
@onready var _timer:        Timer          = %CountdownTimer
@onready var _shopkeeper_line: Label       = %ShopkeeperLine
@onready var _money_label: Label          = %MoneyLabel

var _frame_tweens: Dictionary = {}
var _pack_opening: Control
var _shopkeeper_tween: Tween
var _shopkeeper_chatter_tween: Tween
var _shopkeeper_type_tween: Tween
var _shopkeeper_restore_token := 0
var _shopkeeper_is_thanking := false
var _last_shopkeeper_blip_msec := -100000
var _shopkeeper_blips_enabled := false


func _ready() -> void:
	_pack_opening = PackOpeningScript.new()
	_pack_opening.initialise(self)
	_pack_opening.card_awarded.connect(PlayerStorageData.add_weapon)

	_setup_frame_button(_back_button, _back_frame)
	_back_button.pressed.connect(
		func() -> void:
			_play_sfx("click")
			get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	)
	_timer.timeout.connect(_update_reset_label)
	_populate_shop()
	_update_reset_label()
	_update_money_label()
	var type_duration := _show_random_shopkeeper_line(true)
	_schedule_shopkeeper_chatter(type_duration)


func _unhandled_input(event: InputEvent) -> void:
	_pack_opening.handle_unhandled_input(event)

func _populate_shop() -> void:
	for child in _offers_grid.get_children():
		child.queue_free()

	_offers_grid.add_child(_create_offer({
		"name":        "Basic Weapon Pack",
		"price":       8,
		"description": "A humble pack with a steady chance for stronger weapons.",
		"texture":     BASIC_PACK_TEXTURE,
		"kind":        "pack",
		"pack_id":     "basic",
	}))
	_offers_grid.add_child(_create_offer({
		"name":        "Premium Pack",
		"price":       15,
		"description": "A finer pack that always reveals an unusual or rare weapon.",
		"texture":     PREMIUM_PACK_TEXTURE,
		"kind":        "pack",
		"pack_id":     "premium",
	}))
	for item in _rotating_consumables():
		_offers_grid.add_child(_create_offer(item))


func _rotating_consumables() -> Array:
	var pool   := _all_consumables()
	var chosen : Array = []
	var rng    := RandomNumberGenerator.new()
	rng.seed = _current_reset_block() * 7919 + 31
	while chosen.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		chosen.append(pool[index])
		pool.remove_at(index)
	return chosen


func _all_consumables() -> Array:
	return [
		{ "name": "Magic Ball",  "price": 4, "description": "Predicts the enemy's next weapon.",  "texture": MAGIC_BALL_TEXTURE, "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_MAGIC_BALL },
		{ "name": "Shield",      "price": 2, "description": "Blocks 1 DMG.",                      "texture": SHIELD_TEXTURE,     "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_SHIELD },
		{ "name": "Remedy Kit",  "price": 2, "description": "Removes all ailments (Bleed, Poison).",   "texture": REMEDY_KIT_TEXTURE, "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_REMEDY_KIT },
		{ "name": "Cup-a-Joe",   "price": 2, "description": "Win attacks twice this turn.",       "texture": CUP_A_JOE_TEXTURE,  "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_CUP_A_JOE },
		{ "name": "Snake Oil",   "price": 6, "description": "Inflict 1 poison. If lose twice in a row, inflict 2 instead.", "texture": SNAKE_OIL_TEXTURE,  "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_SNAKE_OIL },
		{ "name": "Pocketwatch", "price": 6, "description": "Raise Aegis for next turn when you lose clash.", "texture": POCKETWATCH_TEXTURE, "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_POCKETWATCH },
		{ "name": "Velvet Gloves", "price": 2, "description": "Cherry pick a card from draw pile.", "texture": VELVET_GLOVES_TEXTURE, "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_VELVET_GLOVES },
		{ "name": "L'Ivoire", "price": 3, "description": "Add random Rare Scissors to deck that lasts entire run.", "texture": L_IVOIRE_TEXTURE, "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_L_IVOIRE },
		{ "name": "Sealed Missive", "price": 3, "description": "Add random Rare Paper to deck that lasts entire run.", "texture": SEALED_MISSIVE_TEXTURE, "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_SEALED_MISSIVE },
		{ "name": "Curio", "price": 3, "description": "Add random Rare Rock to deck that lasts entire run.", "texture": CURIO_TEXTURE, "kind": "consumable", "item_id": PlayerStorageData.CONSUMABLE_CURIO },
	]


func _create_offer(data: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(190.0, 300.0)
	card.add_theme_constant_override("separation", 8)

	# --- Display area (shop frame + item icon) ---
	var display_area := Control.new()
	display_area.custom_minimum_size = Vector2(190.0, 144.0)
	display_area.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	card.add_child(display_area)

	var display := TextureRect.new()
	display.texture        = SHOP_DISPLAY_TEXTURE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	display.offset_left  = -78.0
	display.offset_top   = -58.0
	display.offset_right =  78.0
	display.offset_bottom =  0.0
	display_area.add_child(display)

	var icon_size := Vector2(72.0, 72.0) if data.get("kind", "") == "consumable" else Vector2(86.0, 112.0)
	var icon := TextureRect.new()
	icon.texture        = data["texture"] as Texture2D
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left   = -icon_size.x * 0.5
	icon.offset_top    = -icon_size.y * 0.5 - 14.0
	icon.offset_right  =  icon_size.x * 0.5
	icon.offset_bottom =  icon_size.y * 0.5 - 14.0
	display_area.add_child(icon)

	var name_label := Label.new()
	name_label.text                = str(data["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.64, 1.0))
	card.add_child(name_label)

	# --- Description ---
	var description := Label.new()
	description.text                = str(data["description"])
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0.0, 42.0)
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.78, 0.86, 0.82, 1.0))
	card.add_child(description)

	# --- Buy button ---
	var buy_frame  := _create_button_frame()
	card.add_child(buy_frame)

	var buy_button := Button.new()
	var price := int(data["price"])
	buy_button.text = _format_buy_button_text(price, false)
	buy_button.flat = true
	buy_button.add_theme_font_size_override("font_size", 21)
	buy_button.add_theme_color_override("font_color",         Color(1.0,  0.93, 0.62, 1.0))
	buy_button.add_theme_color_override("font_hover_color",   Color(1.0,  1.0,  0.82, 1.0))
	buy_button.add_theme_color_override("font_pressed_color", Color(0.86, 0.68, 0.3,  1.0))
	for style in ["normal", "hover", "pressed", "focus"]:
		buy_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	buy_frame.add_child(buy_button)
	_setup_frame_button(buy_button, buy_frame)
	buy_button.mouse_entered.connect(
		func() -> void: _set_buy_button_text(buy_button, price, true)
	)
	buy_button.mouse_exited.connect(
		func() -> void: _set_buy_button_text(buy_button, price, false)
	)
	buy_button.button_down.connect(
		func() -> void: _set_buy_button_text(buy_button, price, true)
	)
	buy_button.button_up.connect(
		func() -> void: _set_buy_button_text(buy_button, price, buy_button.is_hovered())
	)
	buy_button.pressed.connect(_on_buy_pressed.bind(buy_button, buy_frame, data))

	return card


func _create_button_frame() -> PixelFramePanel:
	var frame := PixelFramePanel.new()
	frame.custom_minimum_size     = Vector2(132.0, 50.0)
	frame.size_flags_horizontal   = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.base_tint               = Color(0.12, 0.07, 0.12, 1.0)
	frame.frame_outline_tint      = Color(1.0,  0.86, 0.42, 1.0)
	frame.base_outline_tint       = Color(0.26, 0.12, 0.2,  1.0)
	frame.base_fill_tint          = Color(0.12, 0.07, 0.12, 1.0)
	frame.component_scale         = 1.5
	frame.top_right_corner_variant = PixelFramePanel.TopRightCornerVariant.SHINING
	return frame


func _setup_frame_button(button: Button, frame: PixelFramePanel) -> void:
	frame.pivot_offset = frame.size * 0.5
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	button.mouse_entered.connect(_tween_frame.bind(frame, HOVER_SCALE, 0.12))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button, frame))
	button.button_down.connect(_tween_frame.bind(frame, PRESS_SCALE, 0.06))
	button.button_up.connect(_on_button_up.bind(button, frame))


func _on_button_mouse_exited(button: Button, frame: PixelFramePanel) -> void:
	if not button.button_pressed:
		_tween_frame(frame, Vector2.ONE, 0.12)


func _on_button_up(button: Button, frame: PixelFramePanel) -> void:
	_tween_frame(frame, HOVER_SCALE if button.is_hovered() else Vector2.ONE, 0.1)


func _on_buy_pressed(button: Button, frame: PixelFramePanel, data: Dictionary) -> void:
	var price := int(data["price"])
	if not PlayerStorageData.spend_money(price):
		_play_sfx("buzzer")
		_tween_frame(frame, Vector2(0.94, 0.94), 0.06)
		_set_shopkeeper_line("Coin first, confidence later.", true)
		await get_tree().create_timer(0.12).timeout
		if is_instance_valid(frame):
			_tween_frame(frame, HOVER_SCALE if button.is_hovered() else Vector2.ONE, 0.12)
		return

	_play_sfx("chaching")
	_set_buy_button_text(button, price, true)
	_update_money_label()
	_tween_frame(frame, Vector2(1.12, 1.12), 0.08)
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(button):
		_set_buy_button_text(button, price, button.is_hovered())
	if is_instance_valid(frame):
		_tween_frame(frame, HOVER_SCALE if button.is_hovered() else Vector2.ONE, 0.12)
	_show_shopkeeper_thanks()
	if data.get("kind", "") == "pack":
		await _pack_opening.start(str(data.get("pack_id", "basic")), data["texture"] as Texture2D)
	elif data.get("kind", "") == "consumable":
		PlayerStorageData.add_consumable(str(data.get("item_id", "")))


func _tween_frame(frame: PixelFramePanel, target_scale: Vector2, duration: float) -> void:
	if _frame_tweens.has(frame):
		var old_tween := _frame_tweens[frame] as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	tween.tween_property(frame, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_frame_tweens[frame] = tween


func _format_buy_button_text(price: int, show_action: bool) -> String:
	return "BUY $%d" % price if show_action else "$%d" % price


func _set_buy_button_text(button: Button, price: int, show_action: bool) -> void:
	if is_instance_valid(button):
		button.text = _format_buy_button_text(price, show_action)

func _update_reset_label() -> void:
	var seconds_left := maxi(0,
		(_current_reset_block() + 1) * RESET_SECONDS - Time.get_unix_time_from_system()
	)
	_reset_label.text = "CONSUMABLES RESET IN %02d:%02d:%02d" % [
		seconds_left / 3600,
		(seconds_left % 3600) / 60,
		seconds_left % 60,
	]


func _update_money_label() -> void:
	_money_label.text = "$%d" % PlayerStorageData.money()


func _current_reset_block() -> int:
	return int(Time.get_unix_time_from_system() / RESET_SECONDS)


func _show_random_shopkeeper_line(play_blips := false) -> float:
	return _set_shopkeeper_line(str(SHOPKEEPER_LINES.pick_random()), play_blips)


func _show_shopkeeper_thanks() -> void:
	_shopkeeper_restore_token += 1
	var token := _shopkeeper_restore_token
	_shopkeeper_is_thanking = true
	var type_duration := _set_shopkeeper_line(str(SHOPKEEPER_THANKS_LINES.pick_random()), true)

	if _shopkeeper_tween and _shopkeeper_tween.is_valid():
		_shopkeeper_tween.kill()
	if _shopkeeper_chatter_tween and _shopkeeper_chatter_tween.is_valid():
		_shopkeeper_chatter_tween.kill()
	_shopkeeper_tween = create_tween()
	_shopkeeper_tween.tween_interval(
		type_duration + randf_range(
			SHOPKEEPER_THANKS_HOLD_RANGE.x,
			SHOPKEEPER_THANKS_HOLD_RANGE.y
		)
	)
	_shopkeeper_tween.tween_callback(func() -> void:
		if token == _shopkeeper_restore_token:
			_shopkeeper_is_thanking = false
			var next_type_duration := _show_random_shopkeeper_line()
			_schedule_shopkeeper_chatter(next_type_duration)
	)


func _set_shopkeeper_line(line: String, play_blips := false) -> float:
	if not is_instance_valid(_shopkeeper_line):
		return 0.0
	if _shopkeeper_type_tween and _shopkeeper_type_tween.is_valid():
		_shopkeeper_type_tween.kill()
	_shopkeeper_line.text = line
	_shopkeeper_line.visible_characters = 0
	_last_shopkeeper_blip_msec = -100000
	_shopkeeper_blips_enabled = play_blips

	var character_count := line.length()
	var type_duration := float(character_count) * SHOPKEEPER_TYPE_INTERVAL
	_shopkeeper_type_tween = create_tween()
	for visible_count in range(1, character_count + 1):
		_shopkeeper_type_tween.tween_callback(
			_reveal_shopkeeper_character.bind(line, visible_count)
		)
		_shopkeeper_type_tween.tween_interval(SHOPKEEPER_TYPE_INTERVAL)
	return type_duration


func _schedule_shopkeeper_chatter(after_type_duration := 0.0) -> void:
	if _shopkeeper_chatter_tween and _shopkeeper_chatter_tween.is_valid():
		_shopkeeper_chatter_tween.kill()
	_shopkeeper_chatter_tween = create_tween()
	_shopkeeper_chatter_tween.tween_interval(after_type_duration + randf_range(7.0, 11.0))
	_shopkeeper_chatter_tween.tween_callback(func() -> void:
		if _shopkeeper_is_thanking:
			return
		var type_duration := _show_random_shopkeeper_line()
		_schedule_shopkeeper_chatter(type_duration)
	)


func _play_sfx(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	var manager: Node = get_tree().get_first_node_in_group("sfx_manager")
	if manager:
		manager.play_sfx(sfx_name, volume_offset_db)


func _reveal_shopkeeper_character(line: String, visible_count: int) -> void:
	if not is_instance_valid(_shopkeeper_line):
		return
	_shopkeeper_line.visible_characters = visible_count
	if _shopkeeper_blips_enabled and _should_play_shopkeeper_blip(line, visible_count):
		_play_shopkeeper_blip()


func _should_play_shopkeeper_blip(line: String, visible_count: int) -> bool:
	var index := visible_count - 1
	if index < 0 or index >= line.length():
		return false

	var character := line.substr(index, 1)
	if character.strip_edges().is_empty():
		return false
	if ".,!?;:'\"-".contains(character):
		return false

	var now_msec := Time.get_ticks_msec()
	if float(now_msec - _last_shopkeeper_blip_msec) < SHOPKEEPER_BLIP_MIN_INTERVAL * 1000.0:
		return false

	_last_shopkeeper_blip_msec = now_msec
	return true


func _play_shopkeeper_blip() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = SHOPKEEPER_BLIP_STREAM
	player.volume_db = -12.0
	player.pitch_scale = randf_range(0.96, 1.04)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
