extends Control
## Main menu: Play, Caravan, Options, Credits in one centred column,
## with Continue on top when a saved run exists.
## Play starts a run; Options holds the volume sliders; Caravan has three
## tabs: Members (hire with Essence), Wardrobe (Char's outfits) and Milestones (what
## can be unlocked: silhouette until earned, a hint and progress beside it);
## Credits lists who made the game. Every card has
## a Back button, and Esc / gamepad B also goes back.

const Style := preload("res://scripts/ui/ui_style.gd")
const EssenceTracker := preload("res://scripts/ui/essence_tracker.gd")
const VolumeSliders := preload("res://scripts/ui/volume_sliders.gd")
const Defs := preload("res://scripts/game/defs.gd")
const Icons := preload("res://scripts/game/icons.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

signal play_requested

const ITEMS := ["Play", "Caravan", "Options", "Credits"]
const CARAVAN_TABS := ["Members", "Wardrobe", "Milestones"]
const BUTTON_SIZE := Vector2(320, 60)

## Title of the card + one line under "Under Construction".
const PLACEHOLDERS := {}

const CREDITS := [
	["Game design & direction", "[Your name]"],
	["Char the Ember Knight", "[Your name], drawn with Claude"],
	["Music, sound & code", "Made with Claude"],
	["Fonts", "Grenze Gotisch by Omnibus-Type,\nAlegreya Sans by Huerta Tipográfica (SIL OFL)"],
	["Engine", "Godot Engine (MIT License)"],
]

var _items: Array = ITEMS.duplicate()
var _column: VBoxContainer
var _buttons := {}
var _card: PanelContainer
var _card_back: Button
var _last_pick := "Play"
var _busy := false
var _caravan_tab := "Members"
var _tab_buttons := {}
var _tab_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 16)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	if Run.has_save():
		_items.push_front("Continue")
		_last_pick = "Continue"
	for item in _items:
		var b := Button.new()
		b.text = item
		b.custom_minimum_size = BUTTON_SIZE
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_pick.bind(item))
		b.mouse_entered.connect(b.grab_focus)
		_column.add_child(b)
		_buttons[item] = b
	add_child(_column)
	var essence := EssenceTracker.new()
	essence.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	essence.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	essence.offset_right = -20
	essence.offset_top = 16
	add_child(essence)
	_column.modulate.a = 0.0
	visible = false
	resized.connect(_layout)


func _layout() -> void:
	_column.reset_size()
	_column.position = Vector2((size.x - _column.size.x) / 2, size.y * 0.53 - _column.size.y / 2)
	if _card:
		_card.reset_size()
		# Centred under the title, never above it.
		var top := maxf(size.y * 0.27, size.y * 0.6 - _card.size.y / 2)
		_card.position = Vector2((size.x - _card.size.x) / 2, top)


## Fades the buttons in one after another.
func appear(delay := 0.0) -> void:
	visible = true
	_layout()
	_column.modulate.a = 1.0
	var i := 0
	for item in _items:
		var b: Button = _buttons[item]
		b.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(delay + i * 0.09)
		t.tween_property(b, "modulate:a", 1.0, 0.45)
		i += 1
	get_tree().create_timer(delay + 0.1).timeout.connect(func(): _buttons[_items[0]].grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if visible and _card and event.is_action_pressed("ui_cancel"):
		_close_card()
		get_viewport().set_input_as_handled()


func _on_pick(item: String) -> void:
	if _busy or _card:
		return
	_last_pick = item
	if item == "Play" or item == "Continue":
		_busy = true
		Run.resume = item == "Continue"
		play_requested.emit()
	elif item == "Credits":
		_open_card(_credits_card())
	elif item == "Caravan":
		_open_card(_caravan_card())
	elif item == "Options":
		_open_card(_options_card())
	else:
		_open_card(_placeholder_card(PLACEHOLDERS[item][0], PLACEHOLDERS[item][1]))


# ------------------------------------------------------------ cards
func _open_card(card: PanelContainer) -> void:
	_busy = true
	_card = card
	add_child(card)
	_layout()
	_layout.call_deferred()  # again once wrapped text knows its width
	card.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_column, "modulate:a", 0.0, 0.2)
	t.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.12)
	t.chain().tween_callback(func():
		_column.visible = false
		_card_back.grab_focus()
		_busy = false)


func _close_card() -> void:
	if _busy or not _card:
		return
	_busy = true
	var card := _card
	_column.visible = true
	var t := create_tween().set_parallel()
	t.tween_property(card, "modulate:a", 0.0, 0.2)
	t.tween_property(_column, "modulate:a", 1.0, 0.3).set_delay(0.12)
	t.chain().tween_callback(func():
		card.queue_free()
		_card = null
		_buttons[_last_pick].grab_focus()
		_busy = false)


func _base_card(heading: String) -> Array:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var h := Label.new()
	h.text = heading
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 52)
	h.add_theme_color_override("font_color", Style.ACCENT)
	box.add_child(h)
	return [card, box]


func _add_back(box: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	_card_back = Button.new()
	_card_back.text = "Back"
	_card_back.custom_minimum_size = Vector2(200, 54)
	_card_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_back.pressed.connect(_close_card)
	box.add_child(_card_back)


func _placeholder_card(heading: String, line: String) -> PanelContainer:
	var parts := _base_card(heading)
	var box: VBoxContainer = parts[1]
	var sign := Label.new()
	sign.text = "Under Construction"
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_theme_font_override("font", Style.BODY_MEDIUM)
	sign.add_theme_font_size_override("font_size", 30)
	box.add_child(sign)
	var sub := Label.new()
	sub.text = line
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(440, 0)
	sub.add_theme_color_override("font_color", Style.MUTE)
	sub.add_theme_font_size_override("font_size", 22)
	box.add_child(sub)
	_add_back(box)
	return parts[0]


func _options_card() -> PanelContainer:
	var parts := _base_card("Options")
	var box: VBoxContainer = parts[1]
	box.add_child(VolumeSliders.build())
	_add_back(box)
	return parts[0]


func _credits_card() -> PanelContainer:
	var parts := _base_card("Credits")
	var box: VBoxContainer = parts[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in CREDITS:
		var role := Label.new()
		role.text = row[0].to_upper()
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		role.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		role.size_flags_vertical = Control.SIZE_FILL
		role.add_theme_color_override("font_color", Style.MUTE)
		role.add_theme_font_size_override("font_size", 15)
		role.add_theme_constant_override("line_spacing", 0)
		var holder := MarginContainer.new()  # nudge small caps onto the name's baseline
		holder.add_theme_constant_override("margin_top", 5)
		holder.add_child(role)
		grid.add_child(holder)
		var who := Label.new()
		who.text = row[1]
		who.add_theme_font_size_override("font_size", 21)
		who.add_theme_constant_override("line_spacing", -2)
		grid.add_child(who)
	box.add_child(grid)
	_add_back(box)
	return parts[0]


# ------------------------------------------------------------ caravan
## Back on top and bottom; a tab row (Members, Wardrobe, Milestones); then a
## scrolling list for the chosen tab.
func _caravan_card() -> PanelContainer:
	var parts := _base_card("Caravan")
	var card: PanelContainer = parts[0]
	var box: VBoxContainer = parts[1]
	card.custom_minimum_size.x = 640
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	_tab_buttons.clear()
	for t in CARAVAN_TABS:
		var b := Button.new()
		b.text = t
		b.custom_minimum_size = Vector2(180, 48)
		b.toggle_mode = true
		b.button_pressed = t == _caravan_tab
		b.pressed.connect(_show_caravan_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.follow_focus = true
	_tab_scroll.custom_minimum_size = Vector2(600, maxf(220.0, size.y * 0.73 - 300.0))
	box.add_child(_tab_scroll)
	_show_caravan_tab(_caravan_tab)
	_add_back(box)
	return card


func _show_caravan_tab(t: String) -> void:
	_caravan_tab = t
	for k in _tab_buttons:
		_tab_buttons[k].set_pressed_no_signal(k == t)
	for c in _tab_scroll.get_children():
		c.queue_free()
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_tab_scroll.add_child(list)
	_tab_scroll.scroll_vertical = 0
	match t:
		"Members":
			_fill_members(list)
		"Wardrobe":
			_fill_wardrobe(list)
		_:
			_fill_milestones(list)


func _note(text: String, font_size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Style.MUTE)
	l.add_theme_font_size_override("font_size", font_size)
	return l


## Hire members with Essence; hired ones can ride along on a run.
func _fill_members(list: VBoxContainer) -> void:
	list.add_child(_note("Hire members with Essence; they stay hired. Before each run, pick up to %d to ride along on the stagecoach." % Defs.CARAVAN_SEATS))
	for id in Defs.CARAVAN:
		list.add_child(_member_row(id))


func _member_row(id: String) -> Control:
	var m: Dictionary = Defs.CARAVAN[id]
	var got: bool = id in Profile.members
	var row := _row_panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	row.add_child(h)
	var col := Style.ACCENT if got else Color("#b0a69b")
	h.add_child(_icon_box(m["icon"], 76.0, col, true))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	h.add_child(text)
	var name := Label.new()
	name.text = "%s   ·  %s" % [m["name"], m["role"].to_upper()]
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", col if got else Style.FG)
	text.add_child(name)
	var desc := Label.new()
	desc.text = m["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Style.MUTE)
	text.add_child(desc)
	if got:
		var done := Label.new()
		done.text = "Hired"
		done.custom_minimum_size = Vector2(130, 0)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.add_theme_font_size_override("font_size", 20)
		done.add_theme_color_override("font_color", Color("#8fd17f"))
		h.add_child(done)
	else:
		var b := Button.new()
		var cost := int(m["cost"])
		b.text = "Hire  %d" % cost
		b.tooltip_text = "%d Essence" % cost
		b.custom_minimum_size = Vector2(130, 48)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = Profile.essence < cost
		b.pressed.connect(func():
			if Profile.hire(id):
				AudioDirector.play_sfx("chime")
				_show_caravan_tab("Members"))
		h.add_child(b)
	return row


## Outfits for Char: buy with Essence, then pick one to wear.
func _fill_wardrobe(list: VBoxContainer) -> void:
	list.add_child(_note("Buy outfits for Char with Essence; wear any you own."))
	var svg := FileAccess.get_file_as_string("res://assets/char/char_happy.svg")
	for id in Defs.OUTFITS:
		list.add_child(_outfit_row(id, svg))


func _outfit_row(id: String, svg: String) -> Control:
	var o: Dictionary = Defs.OUTFITS[id]
	var got := Profile.has_outfit(id)
	var on := Profile.outfit == id
	var row := _row_panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	row.add_child(h)
	var open := Defs.outfit_open(id, Profile.unlocks)
	h.add_child(_outfit_pic(id, svg, open))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	h.add_child(text)
	var name := Label.new()
	name.text = o["name"]
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Style.ACCENT if on else Style.FG)
	text.add_child(name)
	var desc := Label.new()
	desc.text = o["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Style.MUTE)
	text.add_child(desc)
	if on:
		var done := Label.new()
		done.text = "Wearing"
		done.custom_minimum_size = Vector2(130, 0)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.add_theme_font_size_override("font_size", 20)
		done.add_theme_color_override("font_color", Color("#8fd17f"))
		h.add_child(done)
		return row
	var b := Button.new()
	b.custom_minimum_size = Vector2(130, 48)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	if got:
		b.text = "Wear"
		b.pressed.connect(func():
			Profile.wear(id)
			AudioDirector.play_sfx("chime")
			_show_caravan_tab("Wardrobe"))
	elif not open:
		b.text = "Locked"
		b.disabled = true
		desc.text = Defs.UNLOCKS[o["unlock"]]["hint"]
		name.text = "???"
	else:
		var cost := int(o["cost"])
		b.text = "Buy  %d" % cost
		b.tooltip_text = "%d Essence" % cost
		b.disabled = Profile.essence < cost
		b.pressed.connect(func():
			if Profile.buy_outfit(id):
				Profile.wear(id)
				AudioDirector.play_sfx("chime")
				_show_caravan_tab("Wardrobe"))
	return row


## Char in an outfit, ~80 px wide; a dark silhouette while still locked.
func _outfit_pic(id: String, svg: String, open := true) -> TextureRect:
	var img := Image.new()
	img.load_svg_from_string(Defs.outfit_svg(svg, id), 0.5)
	var pic := TextureRect.new()
	pic.texture = ImageTexture.create_from_image(img)
	pic.custom_minimum_size = Vector2(110, 126)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		pic.modulate = Color("#0b0810")
	return pic


func _row_panel() -> PanelContainer:
	var row := PanelContainer.new()
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_entered.connect(row.grab_focus)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)
	var focus_sb := sb.duplicate()
	focus_sb.border_color = Style.ACCENT
	focus_sb.set_border_width_all(2)
	row.add_theme_stylebox_override("focus", focus_sb)
	return row


func _icon_box(icon: String, px: float, col: Color, lit: bool) -> Control:
	var ic := DrawProxy.new()
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw_fn = func(ci: CanvasItem):
		ci.draw_circle(Vector2(px, px) / 2, px * 0.48, Color(0, 0, 0, 0.3) if lit else Color(1, 1, 1, 0.06))
		Icons.draw(ci, icon, Vector2(px, px) / 2, px * 0.85, col)
	return ic


## The unlock milestones, grouped by type (Oaths, Dice, Misc).
func _fill_milestones(list: VBoxContainer) -> void:
	for t in Defs.UNLOCK_TYPES:
		var h := Label.new()
		h.text = t[1].to_upper()
		h.add_theme_color_override("font_color", Style.MUTE)
		h.add_theme_font_size_override("font_size", 16)
		list.add_child(h)
		var n := 0
		for id in Defs.UNLOCKS:
			if Defs.UNLOCKS[id]["type"] == t[0]:
				list.add_child(_unlock_row(id))
				n += 1
		if n == 0:
			var none := Label.new()
			none.text = "Nothing here yet."
			none.add_theme_color_override("font_color", Style.MUTE)
			none.add_theme_font_size_override("font_size", 18)
			list.add_child(none)


func _unlock_row(id: String) -> Control:
	var u: Dictionary = Defs.UNLOCKS[id]
	var got := Profile.is_unlocked(id)
	var info: Dictionary = Defs.OATHS.get(u["ref"], {}) if u["type"] == "oath" else (Defs.DICE.get(u["ref"], {}) if u["type"] == "die" else (Defs.OUTFITS.get(u["ref"], {}) if u["type"] == "outfit" else Defs.QUICK_REWARDS.get(u["ref"], {})))
	var row := PanelContainer.new()
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_entered.connect(row.grab_focus)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)
	var focus_sb := sb.duplicate()
	focus_sb.border_color = Style.ACCENT
	focus_sb.set_border_width_all(2)
	row.add_theme_stylebox_override("focus", focus_sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	row.add_child(h)
	var px := 76.0
	var ic := DrawProxy.new()
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = Defs.RARITY[info.get("rarity", "common")]["color"] if got else Color("#0b0810")
	ic.draw_fn = func(ci: CanvasItem):
		ci.draw_circle(Vector2(px, px) / 2, px * 0.48, Color(1, 1, 1, 0.06) if not got else Color(0, 0, 0, 0.3))
		Icons.draw(ci, info.get("icon", "rune"), Vector2(px, px) / 2, px * 0.85, col)
	if u["type"] == "outfit":
		h.add_child(_outfit_pic(u["ref"], FileAccess.get_file_as_string("res://assets/char/char_happy.svg"), got))
	else:
		h.add_child(ic)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 4)
	h.add_child(text)
	var name := Label.new()
	name.text = info.get("name", id) if got else "???"
	name.add_theme_font_size_override("font_size", 22)
	if got:
		name.add_theme_color_override("font_color", col)
	text.add_child(name)
	var hint := Label.new()
	hint.text = u["hint"]
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Style.MUTE)
	text.add_child(hint)
	var goal := int(u.get("goal", 1))
	if got:
		var done := Label.new()
		done.text = "Unlocked"
		done.add_theme_font_size_override("font_size", 16)
		done.add_theme_color_override("font_color", Color("#8fd17f"))
		text.add_child(done)
	elif goal > 1:
		var have := mini(Profile.stat(u["stat"]), goal)
		var bar := DrawProxy.new()
		bar.custom_minimum_size = Vector2(0, 22)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw_fn = func(ci: Control):
			var w := minf(ci.size.x - 70.0, 300.0)
			ci.draw_rect(Rect2(0, 6, w, 10), Color(1, 1, 1, 0.1))
			ci.draw_rect(Rect2(0, 6, w * have / goal, 10), Style.ACCENT)
			ci.draw_string(Style.BODY_FONT, Vector2(w + 10, 17), "%d / %d" % [have, goal], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Style.MUTE)
		text.add_child(bar)
	return row
