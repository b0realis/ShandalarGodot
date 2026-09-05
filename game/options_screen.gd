extends Control
## The Options screen — `[QoL]`, because the 1997 game had none.
##
## Every control here is a VIEW of one stored [Settings] key, and where the
## original had a home for a setting, that home keeps its own control over
## the same key: the two sound switches are also on the deck builder's
## mini-menu (`@DECKSURFACE_STANDALONE`), the territory background is also
## in the Duel Options panel. One value, one storage, many views — never a
## parallel copy.
##
## Sound on/off (music and effects separately, as the original separated
## them), music & effects volume, hand display, the rules forks, AI pace —
## persisted immediately through Settings (user://settings.cfg). Grows as
## options do (phase stops, UI scale and colorblind palette are on the
## QoL wishlist in docs/duel-screen-design.md).

## The stone panel's width, and the window it leaves clear top and bottom.
## The panel is anchored to those margins rather than sized to its
## contents, because this list only ever grows.
const PANEL_WIDTH := 460.0
const PANEL_MARGIN := 24.0


func _ready() -> void:
	# The screen and the mixer must agree before a control is drawn: the
	# sliders read Settings, so the buses had better be carrying the same
	# numbers or the readout is a lie.
	GameAudio.apply_settings()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title_bg := GameSkin.texture("title_background")
	if title_bg != null:
		var art := TextureRect.new()
		art.texture = title_bg
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.modulate = Color(0.5, 0.5, 0.5)
		add_child(art)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	# THE PANEL SCROLLS, because the list grows. Options is a screen whose
	# whole job is to accumulate — the sound section alone added four rows
	# on 2026-09-02 — and a centred panel taller than the window loses BOTH
	# ends: a screenshot caught the title clipped at the top and `Back`
	# clipped off the bottom. The scroller is sized to the window with a
	# margin, so the panel is exactly as tall as it can be and no taller.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := UiChrome.panel_around(scroll, 18.0)
	# Anchored rather than centred-on-its-own-size: the panel is as tall as
	# the window allows and the list scrolls inside it. Anchors do the
	# re-fit on a resize, so there is no layout pass to wait for.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = PANEL_MARGIN
	panel.offset_bottom = -PANEL_MARGIN
	add_child(panel)

	var title := UiChrome.body_label("Options", 26)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	_add_sound_section(content)

	content.add_child(UiChrome.body_label("Hand display:"))
	var hand_style := OptionButton.new()
	hand_style.add_item("Fan of cards", 0)
	hand_style.add_item("Stacked list — original style", 1)
	hand_style.selected = 1 if Settings.hand_style() == "stack" else 0
	hand_style.item_selected.connect(func(index: int) -> void:
		Settings.set_value("hand_style", "stack" if index == 1 else "fan"))
	UiChrome.shadowed_button(hand_style)
	content.add_child(hand_style)

	_add_coin_toss_section(content)

	_add_rules_section(content)

	content.add_child(UiChrome.body_label("AI pace in duels (seconds/action):"))
	var pace := HSlider.new()
	pace.min_value = 0.1
	pace.max_value = 1.5
	pace.step = 0.05
	pace.value = Settings.ai_pace()
	pace.value_changed.connect(func(value: float) -> void:
		Settings.set_value("ai_pace", value, false))
	_flush_when_the_drag_ends(pace)
	content.add_child(pace)

	var back := UiChrome.menu_button("Back", Vector2(200, 42))
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/main.tscn"))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back)
	content.add_child(back_row)


## SOUND — TWO SWITCHES AND TWO SLIDERS, and only the switches are 1997's.
##
## The original had **no global options screen**. Its two audio switches
## are entries 8 and 9 of `@DECKSURFACE_STANDALONE`
## (`s30/assets/text/Menus.txt:169-179`) and of `@MAINMENU_STANDALONE`
## (`:218-228`) — `&Music` and `Sound &Effects`, on the deck builder's own
## right-click menu — and the deck builder persists them by name
## (`cfg_write_int(global_cfg_music ? 1 : 0, "Music")`,
## `shandalar-src/src/deck/deckdll.cpp:1296`).
##
## So this whole screen is `[QoL]`, and these two rows are an AGGREGATOR:
## [DeckBuilderScreen]'s mini-menu carries the same two switches, in the
## place 1997 put them, and both views read and write the same
## [Settings] keys. There is one stored value per setting and no parallel
## copy anywhere — the same contract [DuelOptions] states for the
## territory background.
##
## The two SLIDERS are ours outright: `&Music` and `Sound &Effects` are
## on/off in the original and there is no volume anywhere in its string
## tables. They set bus volumes through [GameAudio], which is why dragging
## one is audible in a duel that is already running — the value is not
## copied onto a player at build time any more.
func _add_sound_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Sound:"))

	var effects := CheckButton.new()
	effects.text = "Sound effects"
	effects.tooltip_text = "@DECKSURFACE_STANDALONE — \"Sound Effects\", " \
		+ "the same switch the deck builder's menu carries"
	effects.button_pressed = Settings.sound_enabled()
	effects.toggled.connect(func(on: bool) -> void:
		Settings.set_value("sound_enabled", on)
		GameAudio.apply_settings())
	UiChrome.shadowed_button(effects)
	content.add_child(effects)

	content.add_child(UiChrome.body_label("Effects volume:"))
	content.add_child(_volume_slider("sfx_volume_db", Settings.sfx_volume_db()))

	var music := CheckButton.new()
	music.text = "Music"
	music.tooltip_text = "@DECKSURFACE_STANDALONE — \"Music\", the same " \
		+ "switch the deck builder's menu carries"
	music.button_pressed = Settings.music_enabled()
	music.toggled.connect(func(on: bool) -> void:
		Settings.set_value("music_enabled", on)
		GameAudio.apply_settings())
	UiChrome.shadowed_button(music)
	content.add_child(music)

	content.add_child(UiChrome.body_label("Music volume:"))
	content.add_child(_volume_slider("music_volume_db", Settings.music_volume_db()))

	_add_music_choice(content)


## WHICH TUNE — `[QoL]`, and the answer to a complaint rather than a
## wishlist item.
##
## The 1997 duel plays ONE bed, `Dueltune.wav`, looped
## (`MAGIC.EXE` entry `004ebfef`). It is TEN seconds long (22 050 Hz
## 16-bit stereo, 10.08 s). The owner's
## playtest, 2026-09-03: *"Music in the duel is wrong — now it is
## repeating a short sample — unacceptable. Check music songs available
## (expose this also in music and user can add their own)."*
##
## All three halves of that sentence are this row. **What is available**:
## the original has twenty-seven loopable beds, not one, and
## [MusicLibrary] lists every one it can find. **Expose it**: the picker
## below. **Their own**: `user://music/`, created here with a README in
## it, exactly the way the battle-setup screen creates `user://portraits/`.
##
## ONE STORED VALUE, MANY VIEWS — the contract the two sound switches
## above already keep. The key is `music_choice` and [MusicLibrary] owns
## its meaning; this screen is a view of it and never a second copy.
func _add_music_choice(content: VBoxContainer) -> void:
	# Creating the folder is what makes the README appear, and the README
	# is how a player learns the format without opening a manual. Same
	# gesture, same reason, as [method PortraitLibrary.ensure_folder] on
	# the setup screen.
	var folder := MusicLibrary.ensure_folder()
	MusicLibrary.refresh()
	var tracks := MusicLibrary.all()

	content.add_child(UiChrome.body_label("Music:"))
	var picker := OptionButton.new()
	picker.add_item("Shuffle all tracks", 0)
	picker.set_item_tooltip(0, "Whole tracks, one after another, "
		+ "crossfaded — %d of them" % tracks.size())
	picker.add_item("1997 — one tune per screen, looped", 1)
	picker.set_item_tooltip(1, "What the original did: Dueltune.wav in a "
		+ "duel, one LocMus track in the deck builder")
	var chosen := MusicLibrary.choice()
	var selected := 1 if chosen == MusicLibrary.CHOICE_ORIGINAL else 0
	for i in tracks.size():
		var entry: Dictionary = tracks[i]
		var id := 2 + i
		picker.add_item(String(entry["name"]), id)
		picker.set_item_tooltip(id, "Just this one, on repeat"
			+ ("  (yours)" if bool(entry["mine"]) else ""))
		if entry["id"] == chosen:
			selected = picker.item_count - 1
	picker.selected = selected
	picker.item_selected.connect(func(index: int) -> void:
		var id := picker.get_item_id(index)
		if id == 0:
			MusicLibrary.set_choice(MusicLibrary.CHOICE_SHUFFLE)
		elif id == 1:
			MusicLibrary.set_choice(MusicLibrary.CHOICE_ORIGINAL)
		else:
			MusicLibrary.set_choice(String(tracks[id - 2]["id"]))
		# The next screen that starts music takes the new order; a session
		# that has already shuffled should not keep the old one.
		MusicPlayer.reset_order())
	UiChrome.shadowed_button(picker)
	content.add_child(picker)

	# SAY WHERE THE FOLDER IS, in the screen rather than in a tooltip
	# nobody hovers — the same habit the coin-toss row keeps for a reason
	# it cannot offer something.
	var line := "No tracks yet. " if tracks.is_empty() else \
		"%d track%s. " % [tracks.size(), "" if tracks.size() == 1 else "s"]
	if tracks.is_empty():
		line += "Import your copy of the 1997 game, or drop "
		line += "WAV/OGG/MP3 files in:\n%s" % folder
	else:
		line += "Add your own — WAV, OGG or MP3 — in:\n%s" % folder
	var why := UiChrome.body_label(line, 12)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = PANEL_WIDTH - 64.0
	why.modulate = Color(1, 1, 1, 0.65)
	content.add_child(why)


## THE OPENING COIN TOSS — `[QoL]`, and the FULL view of a value whose
## 1997 view is a checkbox.
##
## `Show coin flip animations` (`@DIALOG_DUELOPTIONS`,
## `s30/assets/text/Uistrings.txt:604`) is a BOOL in the original, and it
## gated one thing: whether the pre-rendered movie played. The Duel
## Options panel still carries that checkbox, over the same
## `ShowCoinFlips` key; this list is the same value with its third
## position exposed. One stored value, two views — the contract
## [DuelOptions] states for the territory background and the deck
## builder's two sound switches.
##
## THE FIRST ENTRY IS USUALLY UNAVAILABLE, and says so rather than
## disappearing — the original's own habit (*"greys what it cannot
## offer"*, `Duel.hlp`, **Territory**), the same one [TerritoryMenu] and
## the rules forks above follow. `COINTOSS_Heads.AVI` /
## `COINTOSS_Tails.AVI` ship only with the 1997 game, so a player who has
## not imported it sees the entry, learns what it needs, and gets our
## animation instead — [method CoinToss.effective_style] does the
## substitution, and it falls back to the RECREATION rather than to
## instant: someone who asked to watch the toss should still watch it.
func _add_coin_toss_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Opening coin toss:"))

	var have_video := CoinToss.video_available()
	var picker := OptionButton.new()
	# THE PICKER SHOWS WHAT WILL ACTUALLY HAPPEN, not what is stored. A
	# player who chose the movie on a machine that has it, and then opens
	# this screen on one that does not, is shown `Our coin animation` —
	# which is what the next duel will do — while the stored value stays
	# `video`, so importing the original later gives them the movie back
	# without their having to ask twice.
	var chosen := CoinToss.current_style()
	for i in DuelOptions.COIN_FLIP_STYLES.size():
		var row: Dictionary = DuelOptions.COIN_FLIP_STYLES[i]
		picker.add_item(String(row["label"]), i)
		picker.set_item_tooltip(i, String(row["blurb"]))
		if row["key"] == DuelOptions.COIN_VIDEO and not have_video:
			picker.set_item_disabled(i, true)
			picker.set_item_tooltip(i, CoinToss.VIDEO_MISSING)
		if row["key"] == chosen:
			picker.selected = i
	picker.item_selected.connect(func(index: int) -> void:
		DuelOptions.set_coin_flip_style(
			String(DuelOptions.COIN_FLIP_STYLES[index]["key"])))
	UiChrome.shadowed_button(picker)
	content.add_child(picker)

	# SAY WHY, in the screen rather than in a tooltip nobody hovers: a
	# greyed line that gives no reason is just a broken option.
	if not have_video:
		var why := UiChrome.body_label(CoinToss.VIDEO_MISSING, 12)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = PANEL_WIDTH - 64.0
		why.modulate = Color(1, 1, 1, 0.65)
		content.add_child(why)


## THE RULES FORKS. The original enforced the FIFTH EDITION rules (manual
## p.108) where our engine cites the modern Comprehensive Rules, and the
## two genuinely disagree in a handful of places. Each is a switch here,
## with a preset that flips them all — and a fork that is not implemented
## yet is shown DISABLED rather than offered as a switch that does
## nothing. RulesOptions.FORKS is the single source for this list.
func _add_rules_section(content: VBoxContainer) -> void:
	var heading := UiChrome.body_label("Rules — 1997 (Fifth Edition) or modern:")
	content.add_child(heading)

	var boxes: Dictionary = {}
	var preset := OptionButton.new()
	preset.add_item("Modern rules", 0)
	preset.add_item("1997 — Fifth Edition", 1)
	preset.add_item("Custom", 2)
	UiChrome.shadowed_button(preset)
	content.add_child(preset)

	var live := RulesOptions.new()
	for fork in RulesOptions.FORKS:
		var key: String = fork["key"]
		live.set_fork(key, Settings.rule(key))
		var row := CheckButton.new()
		row.text = fork["label"]
		var ready_yet: bool = RulesOptions.IMPLEMENTED.has(key)
		row.disabled = not ready_yet
		row.tooltip_text = "1997: %s\nModern: %s\nSource: %s%s" % [
			fork["fifth"], fork["modern"], fork["source"],
			"" if ready_yet else "\n\nNOT IMPLEMENTED YET — see docs/duel-todo.md §6.20."]
		# Clicking the NAME explains the rule; clicking the switch flips
		# it. A disabled row still explains itself — that is the whole
		# point of showing an unbuilt fork rather than hiding it.
		var explain := Button.new()
		explain.text = "?"
		explain.custom_minimum_size = Vector2(26, 0)
		explain.tooltip_text = "What this rule means"
		UiChrome.shadowed_button(explain)
		explain.pressed.connect(_explain_rule.bind(fork))
		row.button_pressed = Settings.rule(key)
		row.toggled.connect(func(on: bool) -> void:
			Settings.set_rule(key, on)
			live.set_fork(key, on)
			preset.selected = _preset_index(live.edition()))
		UiChrome.shadowed_button(row)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.add_child(row)
		line.add_child(explain)
		content.add_child(line)
		boxes[key] = row

	preset.selected = _preset_index(live.edition())
	preset.item_selected.connect(func(index: int) -> void:
		if index == 2:
			return       # "Custom" is a readout, not a command
		live.set_edition("fifth" if index == 1 else "modern")
		for key in boxes:
			var on: bool = live.get_fork(key)
			# In memory per fork and ONE write for the gesture — the
			# sliders' rule; this loop used to write the file seven times.
			Settings.set_rule(key, on, false)
			boxes[key].set_pressed_no_signal(on)
		Settings.flush())


## The rule's own explanation, on the era's stone panel with an OK button
## — both editions' behaviour and the source it was taken from, so a
## player can see WHY a switch exists and where the answer came from.
func _explain_rule(fork: Dictionary) -> void:
	var built: bool = RulesOptions.IMPLEMENTED.has(fork["key"])
	var body := "1997 (Fifth Edition):\n%s\n\nModern rules:\n%s\n\nSource: %s" % [
		fork["fifth"], fork["modern"], fork["source"]]
	if not built:
		body += "\n\nThis rule is not implemented yet, so the switch is "
		body += "disabled. See docs/duel-todo.md §6.20."
	UiChrome.explain_popup(self, fork["label"], body)


static func _preset_index(edition: String) -> int:
	match edition:
		"modern": return 0
		"fifth": return 1
	return 2


func _volume_slider(key: String, current: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = current
	slider.value_changed.connect(func(value: float) -> void:
		# In memory only: a drag fires this on every pixel, and the file
		# is written once when the handle is let go (below).
		Settings.set_value(key, value, false)
		# Straight onto the bus, so a duel behind this screen changes
		# while the handle is moving. That is the whole point of mixing on
		# buses rather than copying the number onto a player.
		GameAudio.apply_settings())
	_flush_when_the_drag_ends(slider)
	return slider


## Every slider on this screen applies each tick and SAVES once: when the
## mouse drag ends, when keyboard focus leaves it (arrow keys change the
## value with no drag to end), and — in [method _exit_tree] — when the
## screen itself goes, whichever way it goes.
static func _flush_when_the_drag_ends(slider: HSlider) -> void:
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Settings.flush())
	slider.focus_exited.connect(func() -> void:
		Settings.flush())


func _exit_tree() -> void:
	Settings.flush()
