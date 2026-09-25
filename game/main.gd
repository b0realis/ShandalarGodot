class_name MainScreen
extends Control
## Title screen — the stone menu column over the original title art,
## plus the corner wordmark, card sets, version and future Manalink entry.
## Magic Battle opens setup; SGManalink opens an isolated local playtest.
## The adventure mode (M5) will grow this menu; the flow stays:
## menu -> setup -> duel.


## The shell column's button size. Eight entries have to sit clear of the
## title art's own lettering; see the column in [method _ready].
const MENU_BUTTON := Vector2(228, 36)
## The gap between them.
const MENU_GAP := 6
## Letters to match: the default 22 is cut by a 36px-high frame.
const MENU_FONT := 21
## Faked weight — MagicMedieval ships no bold ([method UiChrome.menu_button]).
const MENU_BOLD := 0.05
## [QoL] The future online mode's square, separate from the menu column.
const MANALINK_SIZE := Vector2(72, 72)



## The flag that turns the shipped game into the Deck Lab.
##
## THE EXPORTED BINARY WILL NOT RUN `--script`. That flag is honoured by
## the editor and by a debug template; a release template ignores it and
## launches the game instead (measured 2026-09-05: the process simply ran
## the title screen until the timeout killed it). So the lab cannot be
## reached from outside — it has to be let in from the inside, and the
## title screen is the first of our code that runs.
##
## The cost is one string comparison before anything is built, and the
## gain is that a player who downloaded a 296 MB zip has the same
## thousand-game deck tester the developers use, against the same engine
## that just played their duel. `DeckLab/README.md` is its manual and
## ships beside the binary.
const DECK_LAB_FLAG := "--deck-lab"
## The Lab's feeder by the same door (2026-09-25): `auto_deck.sh` in a
## release is `--auto-deck`, and DeckLab/auto_deck_cli.gd builds the
## field the Lab then plays.
const AUTO_DECK_FLAG := "--auto-deck"
## Release-only integration probe: validates a real external ZIP, activates
## its dormant trusted scripts, checks every set-specific art pair, then exits.
const VERIFY_PACK_1_FLAG := "--verify-pack-1"
const VERIFY_PACK_2_FLAG := "--verify-pack-2"
const VERIFY_PACK_3_FLAG := "--verify-pack-3"
const VERIFY_PACK_4_FLAG := "--verify-pack-4"
const VERIFY_PACK_5_FLAG := "--verify-pack-5"

## The corner line that reports a skin zip on its way (web builds).
var _fetching: Label
var _manalink_notice: Control
var _pack_notice: Control
var _pack_warning: Control
var _version_label: Label


func _ready() -> void:
	# BEFORE THE SCREEN IS BUILT, and before the card pool is loaded: the
	# lab loads its own and the shell has nothing to contribute to a
	# headless run.
	if OS.get_cmdline_user_args().has(DECK_LAB_FLAG):
		_run_headless_tool(DECK_LAB_FLAG, "res://DeckLab/simulate.gd")
		return
	if OS.get_cmdline_user_args().has(AUTO_DECK_FLAG):
		_run_headless_tool(AUTO_DECK_FLAG, "res://DeckLab/auto_deck_cli.gd")
		return
	if OS.get_cmdline_user_args().has(VERIFY_PACK_1_FLAG):
		_verify_exported_pack_1()
		return
	if OS.get_cmdline_user_args().has(VERIFY_PACK_2_FLAG):
		_verify_exported_pack_2()
		return
	if OS.get_cmdline_user_args().has(VERIFY_PACK_3_FLAG):
		_verify_exported_pack_3()
		return
	if OS.get_cmdline_user_args().has(VERIFY_PACK_4_FLAG):
		_verify_exported_pack_4()
		return
	if OS.get_cmdline_user_args().has(VERIFY_PACK_5_FLAG):
		_verify_exported_pack_5()
		return
	CardRegistry.ensure_loaded()
	var title_bg := GameSkin.texture("title_background")
	if title_bg != null:
		var bg := TextureRect.new()
		bg.texture = title_bg
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# Lower-right, clear of the big Magic logo and "The Gathering" text.
	#
	# THE COLUMN IS SIZED BY WHAT IT MUST CLEAR. Eight entries at the old
	# 260x46 would reach up into "The Gathering" — the 2026-09-03 playtest
	# asked for the menu "juuust a little bit" left and lower with smaller
	# buttons, which is the same instruction stated as a measurement: the
	# painting's title text ends around y=400 of 800, so eight buttons,
	# their gaps and the bottom inset have to fit in what is below it.
	var box := VBoxContainer.new()
	box.name = "MenuColumn"
	box.add_theme_constant_override("separation", MENU_GAP)
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# With grow BEGIN, position marks the BOTTOM-RIGHT corner the column
	# grows up-left from.
	#
	# X IS MEASURED OFF THE PAINTING, not guessed. The 2026-09-04 playtest
	# asked for the column centred under "The Gathering". `Shellscreen`
	# is 640x480 shown COVERED in a 1280x800 window, so it scales x2 and
	# the horizontal mapping is exactly 2x: the subtitle's lettering runs
	# x=612..1178 on screen (the (R) sits outside it, at 1205), so its
	# centre is 895. A 228-wide column centred there has its right edge at
	# 1009, which is 271 in from the right anchor.
	#
	# Y IS MEASURED THE SAME WAY, and the strip is TIGHT. The subtitle's
	# lowest ink is not its baseline but the descender of "Gathering"'s
	# g, which reaches y=432; the screen ends at 800. That leaves 368px
	# for a column that stood 358 tall, i.e. TEN pixels of slack, spent
	# 6 above and 4 below — which is why Exit sat on the screen edge
	# (2026-09-04 playtest). Air at the bottom therefore had to be bought,
	# not moved: [constant MENU_GAP] went 10 -> 6, freeing 28px, and the
	# inset went 4 -> 26. The column is now 330 tall at y=444..774 — 12px
	# clear of the g and 26 clear of the edge, and its mass sits 8px
	# higher than before.
	box.position += Vector2(-271, -26)
	add_child(box)

	var battle := _menu_button("Magic Battle")
	battle.pressed.connect(_open.bind("res://game/setup_screen.tscn"))
	box.add_child(battle)

	# THE GAUNTLET — the fourth 1997 duel mode, and until now the only one
	# this project had never had. `@SHELLSCREEN_DUEL`
	# (`Program/UIStrings.txt:5-11`) lists the shell's four duel modes with
	# their own one-line descriptions and NUMBERS them; the gauntlet is
	# entry 2, directly under `1Solo &Duel` — which is our Magic Battle —
	# so it sits directly under it here. The tooltip is the entry's own
	# description, after the colon, exactly as Deck Builder's is:
	#     `2&Gauntlet:Defeat as many opponents in a row as possible.`
	var gauntlet := _menu_button("Gauntlet")
	gauntlet.tooltip_text = "Defeat as many opponents in a row as possible."
	gauntlet.pressed.connect(
		_open.bind("res://game/duel/gauntlet_screen.tscn"))
	box.add_child(gauntlet)

	# THE TWO THAT ARE NOT BUILT YET, in the order the 1997 shell would
	# have them: the adventure this project is named after (M5,
	# `docs/ROADMAP.md`) and the save/load the shell keeps beside it.
	# Placeholders on the owner's instruction (2026-09-03) — they are
	# ENABLED rather than greyed, because a disabled button in Godot
	# swallows its own tooltip and a player deserves to be told WHY a
	# front door is shut. Each opens one sentence.
	var shandalar := _menu_button("Shandalar")
	shandalar.pressed.connect(func() -> void:
		UiChrome.explain_popup(self, "Shandalar",
			"The adventure — the world map, its cities and dungeons, the "
			+ "wizards who hold the five castles, and the ante you play "
			+ "them for. Not built yet: this is milestone M5, and the "
			+ "duel it will be played through is what exists today."))
	box.add_child(shandalar)

	var save_load := _menu_button("Save / Load")
	save_load.pressed.connect(func() -> void:
		UiChrome.explain_popup(self, "Save / Load",
			"Nothing to save yet. A duel is one sitting, and the "
			+ "adventure that would need a saved game is not built. "
			+ "Decks you build ARE kept — the Deck Builder writes them "
			+ "into your own folder and they are there next time."))
	box.add_child(save_load)

	# `@SHELLSCREEN_TOOLS` (shandalar-src/Program/UIStrings.txt) lists the
	# original shell's Tools page as "&Deck Builder:Build or Modify decks."
	# — the button's label and, after the colon, its own description, which
	# the 1997 shell showed as a status line and we show as a cue card.
	var deck_builder := _menu_button("Deck Builder")
	deck_builder.tooltip_text = "Build or Modify decks."
	deck_builder.pressed.connect(
		_open.bind("res://game/deck_builder/deck_builder_screen.tscn"))
	box.add_child(deck_builder)

	var options := _menu_button("Options")
	options.pressed.connect(_open.bind("res://game/options_screen.tscn"))
	box.add_child(options)

	# HELP — directly above Exit, per the owner. The 1997 game reached its
	# help by right-clicking the dueling table (manual p.14: "One of the
	# options is Help"); we have no such context menu, so the reference gets
	# a front door on the shell instead. `game/help/help_screen.gd`.
	var help := _menu_button("Help")
	help.tooltip_text = "The mana, the rules, and every icon — explained."
	help.pressed.connect(_open.bind("res://game/help/help_screen.tscn"))
	box.add_child(help)

	var exit_button := _menu_button("Exit")
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(exit_button)


	# A bottom-right stack keeps the globe immediately above the version,
	# with download progress above BOTH so web fetching never covers it.
	var status := VBoxContainer.new()
	status.name = "OnlineCorner"
	status.add_theme_constant_override("separation", 6)
	status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	status.position += Vector2(-10, -8)
	add_child(status)

	# THE ART ON ITS WAY. A web build with no skin stored fetches the skin
	# and card packs from beside its page. Reserve only the available corner
	# width; a long progress line wraps instead of crossing the main menu.
	var fetching := Label.new()
	fetching.name = "Fetching"
	_corner_label(fetching, 12)
	fetching.custom_minimum_size.x = 240.0
	fetching.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fetching.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fetching.visible = SkinPack.busy()
	fetching.text = SkinPack.transfer_line(SkinPack.fetch_progress())
	status.add_child(fetching)
	_fetching = fetching
	SkinPack.fetch_progressed.connect(_on_fetch_progressed)

	# [QoL] Owner request, 2026-09-13: a square shell button wearing a
	# green globe, reserved for Manalink online games. Enabled, like the
	# adventure placeholder, so mouse and keyboard can ask what it is.
	var online := UiChrome.menu_button("", MANALINK_SIZE, MENU_FONT, MENU_BOLD)
	online.name = "Manalink"
	online.tooltip_text = "SGManalink - LAN multiplayer playtest with temporary names. Internet games are coming later."
	online.size_flags_horizontal = Control.SIZE_SHRINK_END
	online.pressed.connect(_open_manalink_notice)
	status.add_child(online)
	var globe := ManalinkGlobe.new()
	globe.name = "Globe"
	online.add_child(globe)
	globe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 10.0)

	# Version tag stays at the bottom-right corner beneath the new button.
	var version := Label.new()
	version.name = "Version"
	_version_label = version
	_refresh_version()
	_corner_label(version, 12)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(version)

	# THE WORDMARK OVER THE CARD POOL, bottom-left. Both were here before
	# in some form — the name in this corner at 16px, the badges up in the
	# TOP-left — and the 2026-09-03 playtest asked for them stacked: the
	# badges down here, the name above them, and the name bigger. They say
	# two halves of one thing (what this is called, what it is made of), so
	# they now read as one mark instead of two unrelated corners.
	#
	# The column grows UP and RIGHT from the bottom-left corner, the mirror
	# of the button column's up-and-left.
	var corner := VBoxContainer.new()
	corner.name = "CatalogueCorner"
	corner.add_theme_constant_override("separation", 8)
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.grow_horizontal = Control.GROW_DIRECTION_END
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.position += Vector2(10, -8)
	add_child(corner)

	# Still the corner voice, not UiChrome's: this label sits on the title
	# PAINTING, whose bottom-left third measures 69/255 (PIL, 2026-09-03),
	# and pale ink on a hard shadow is what carries there. UiChrome's dark
	# INK is for text on the sandstone panels, which this is not.
	var wordmark := Label.new()
	wordmark.text = "ShandalarGodot"
	_corner_label(wordmark, 34)
	wordmark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	corner.add_child(wordmark)

	# THE CARD POOL: a row of badges saying which expansions this game is
	# made of. One per CardRegistry.SET_ORDER, a 1997 expansion symbol
	# where the original drew one and letters where it did not
	# (`game/set_badges.gd` carries the evidence for which is which). It
	# sits on a stone plaque rather than bare on the art like the wordmark:
	# that is TEXT, which the corner ink and its one-pixel shadow can carry
	# on any ground, while a 22px symbol on the title painting's own busy
	# stonework cannot.
	# Each badge answers a click with its set's own window: the date, how
	# much of it is in this game, and what the set was (the owner's ask,
	# 2026-09-03 — "each icon should be clickable with a mini popup ...
	# and mini lore info"). SetBadges knows the facts; the shell decides
	# where the window opens, which is what the signal is for.
	var row := SetBadges.new()
	row.name = "OriginalSets"
	row.set_clicked.connect(func(code: String) -> void:
		var facts := SetBadges.facts_for(code)
		UiChrome.explain_popup(self, String(facts.get("name", code)),
			SetBadges.describe(code), 520.0))
	var badges := UiChrome.panel_around(row, 8.0)
	badges.name = "OriginalSetPlaque"
	badges.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badges.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# [QoL] Numbered packs now have their own line below the original
	# plaque, not an ever-widening extension of the 1997 set strip.
	var pool_row := VBoxContainer.new()
	pool_row.name = "CardPool"
	pool_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pool_row.add_theme_constant_override("separation", 6)
	pool_row.add_child(badges)
	var packs := CardPackBadges.new()
	packs.name = "PackBadges"
	packs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	packs.pack_clicked.connect(_open_pack_notice)
	pool_row.add_child(packs)
	corner.add_child(pool_row)
	CardPacks.changed.connect(_on_card_pack_changed)
	CardPacks.rescanned.connect(_refresh_version)

	# THE TITLE SCREEN HAS MUSIC, and it is the SHELL'S — one bed, looping,
	# held by the `ShellMusic` autoload so it carries on unbroken into
	# Magic Battle, Options and Help and back. That file says what the
	# 1997 shell played (nothing) and how the bed was picked. The screens
	# with a bed of their own stop it when they start theirs, so this
	# screen has nothing to do on the way out.
	ShellMusic.play()


## The fetch line follows the pack's own flag, not the signal alone: a
## -1 at the end of a download is "gone", not "unknown".
func _on_fetch_progressed(fraction: float) -> void:
	_fetching.visible = SkinPack.busy()
	_fetching.text = SkinPack.transfer_line(fraction)


func _refresh_version() -> void:
	if _version_label == null:
		return
	var version := String(ProjectSettings.get_setting(
		"application/config/version", "dev"))
	if CardRegistry.optional_pack_enabled() or not CardRegistry.extra_set_order().is_empty():
		_version_label.text = "v%s · %s set entries · %s unique cards" % [version,
			_grouped(CardRegistry.named_set_entry_count()), _grouped(CardRegistry.size())]
	else:
		_version_label.text = "v%s · %d cards" % [version, CardRegistry.size()]


static func _grouped(value: int) -> String:
	var digits := str(value)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return digits + out


func _on_card_pack_changed(_id: String, _enabled: bool) -> void:
	_refresh_version()


func _open_pack_notice(id: String) -> void:
	if is_instance_valid(_pack_notice):
		return
	var info := CardPacks.info(id)
	if info.is_empty():
		return
	var enabled := CardPacks.is_enabled(id)
	var counts: Dictionary = info.get("counts", {})
	var body := "%s\n\n" % String(info.get("description", ""))
	body += "Status: %s\n\n" % ("Enabled" if enabled else "Disabled")
	body += "%s adds %s named set entries: %s cross-set reprints and " % [
		CardPacks.label_for(id),
		_grouped(int(counts.get("pack_card_entries", 0))),
		_grouped(int(counts.get("reprint_entries", 0)))]
	body += "%d new rules identities. This pack's checklists contain " % \
		int(counts.get("new_rules_identities", 0))
	body += "%s set entries representing %d unique cards. The catalog " % [
		_grouped(int(counts.get("named_set_entries", 0))),
		int(counts.get("distinct_cards", 0)),
	]
	body += "preserves %s published collector slots.\n\n" % \
		_grouped(int(counts.get("published_printings", 0)))
	if id == CardPacks.ID:
		body += "The four new identities are Chaos Orb, Word of Command, "
		body += "Shahrazad, and Falling Star. "
	body += String(info.get("rules_note", ""))
	var refusal := CardPacks.change_refusal()
	if not refusal.is_empty(): body += "\n\n" + refusal
	_pack_notice = UiChrome.action_popup(self, "%s — %s" % [
		CardPacks.label_for(id), info.get("name", "Card pack")], body, [
		{"label": "Enable", "name": "Enable", "disabled": enabled or not refusal.is_empty(),
			"callable": CardPacks.set_enabled.bind(id, true)},
		{"label": "Disable", "name": "Disable", "disabled": not enabled or not refusal.is_empty(),
			"callable": _request_disable_pack.bind(id)},
		{"label": "Close", "name": "Close"},
	], 620.0)
	_pack_notice.tree_exited.connect(func() -> void: _pack_notice = null)


func _request_disable_pack(id: String) -> void:
	var warning := CardPacks.disable_warning(id)
	if warning == "":
		CardPacks.set_enabled(id, false)
		return
	if is_instance_valid(_pack_warning):
		return
	_pack_warning = UiChrome.action_popup(self, "Current deck uses " + CardPacks.label_for(id),
		warning, [
			{"label": "Keep enabled", "name": "KeepEnabled"},
			{"label": "Disable anyway", "name": "DisableAnyway",
				"callable": CardPacks.set_enabled.bind(id, false)},
		], 570.0)
	_pack_warning.tree_exited.connect(func() -> void: _pack_warning = null)


## Opening the lobby does not start a listener or connect automatically.
func _open_manalink_notice() -> void:
	if is_instance_valid(_manalink_notice):
		return
	_manalink_notice = SgLobby.new()
	add_child(_manalink_notice)


## Hand the rest of the command line to the Deck Lab and quit with its
## exit code.
##
## `simulate.gd` and `auto_deck_cli.gd` extend [SceneTree] because each
## is normally the whole program; constructed here the tool is an
## ordinary Object that happens to build a root window, so it is freed
## explicitly rather than left to a queue it never reaches. Nothing of
## the shell is touched — this function does not return.
func _run_headless_tool(flag: String, script_path: String) -> void:
	var args := OS.get_cmdline_user_args()
	var forwarded := PackedStringArray()
	for arg in args:
		if arg != flag:
			forwarded.append(arg)
	var tool: Object = load(script_path).new()
	var code := 1
	if tool.has_method("_main"):
		code = int(tool.call("_main", forwarded))
	tool.free()
	get_tree().quit(code)


func _verify_exported_pack_1() -> void:
	var was_enabled := Settings.enabled_card_packs().has(CardPacks.ID)
	var failures: Array[String] = []
	if not CardPacks.has_pack(CardPacks.ID):
		failures.append("the exact ZIP was not discovered or validated")
	elif not CardPacks.set_enabled(CardPacks.ID, true):
		failures.append("Pack 1 could not be enabled")
	else:
		if CardRegistry.size() != 901 \
				or CardRegistry.named_set_entry_count() != 1270:
			failures.append("the enabled registry did not reach 901 / 1,270")
		for name in CardPacks.ADDED_NAMES:
			if not CardRegistry.has_card(name):
				failures.append("dormant card script missing: " + name)
		var orb := CardRegistry.get_card("Chaos Orb") if \
			CardRegistry.has_card("Chaos Orb") else null
		var star := CardRegistry.get_card("Falling Star") if \
			CardRegistry.has_card("Falling Star") else null
		if orb == null or orb.activated_abilities.is_empty() \
				or not (orb.activated_abilities[0].effects[0] is RandomDestroyEffect):
			failures.append("Chaos Orb's exported effect script did not load")
		if star == null or star.spell_effects.is_empty() \
				or not (star.spell_effects[0] is CoinFlipDamageEffect):
			failures.append("Falling Star's exported effect script did not load")
		var art_count := 0
		for row in CardPacks.entry_records(CardPacks.ID):
			for full_card in [false, true]:
				if CardPacks.art_path(String(row.get("name", "")),
						String(row.get("set", "")), full_card) == "":
					failures.append("mounted artwork missing: %s / %s" % [
						row.get("set", ""), row.get("name", "")])
				else:
					art_count += 1
		if art_count != 746:
			failures.append("expected 746 mounted set-art files, found %d" % art_count)
	CardPacks.set_enabled(CardPacks.ID, was_enabled)
	if failures.is_empty():
		print("PACK 1 EXPORT VERIFY OK — 901 identities, 1,270 set entries, "
			+ "746 set-art files, dormant scripts loaded")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("PACK 1 EXPORT VERIFY FAILED: " + failure)
		get_tree().quit(2)


## Export probe changes enablement in memory only, never player settings.
func _verify_exported_pack_2() -> void:
	var before := Settings.enabled_card_packs()
	var failures: Array[String] = []
	if not CardPacks.has_pack(FallenEmpiresPack.ID):
		failures.append("the exact Pack 2 ZIP was not discovered or validated")
	else:
		Settings.set_value("enabled_card_packs", [FallenEmpiresPack.ID], false)
		CardPacks._configure_registry()
		CardRegistry.ensure_loaded()
		if CardRegistry.size() != 999 or CardRegistry.names_in_set("fem").size() != 102:
			failures.append("expected 999 identities including 102 Fallen Empires cards")
		for name in FallenEmpiresPack.names():
			if not CardRegistry.has_card(name):
				failures.append("missing dormant implementation: " + name)
			for full in [false, true]:
				var path := CardPacks.art_path(name, "fem", full)
				if path == "" or Image.load_from_file(path) == null:
					failures.append("missing or unreadable artwork: " + name)
		var thallid := CardRegistry.get_card("Thallid") if CardRegistry.has_card("Thallid") else null
		if thallid == null or not thallid.activated_abilities[0].effects[0] is CreateTokenEffect:
			failures.append("the exported shared token effect did not load")
		for key in ["set_icon_fem", "filter_fem_on", "filter_fem_off",
				"filter_source_on", "filter_source_off", "filter_pack1_on", "filter_pack1_off"]:
			var symbol := GameSkin.our_art(key)
			if symbol == null or symbol.get_image().is_empty():
				failures.append("missing exported crown/medallion artwork: " + key)
		# Exercise the shipped cost-first planner, not just metadata loading.
		var probe := MtgGame.new()
		probe.setup(["Forest", "Forest"], ["Forest", "Forest"])
		probe.start(0)
		for name in ["Forest", "Implements of Sacrifice"]:
			var inst := CardInstance.new(CardRegistry.get_card(name), probe._next_instance_id, 0)
			probe._next_instance_id += 1
			probe._instances[inst.id] = inst
			probe._put_on_battlefield(inst, 0)
		var cost := ManaCost.parse("{B}{B}")
		var plan := ManaPlanner.plan(probe, 0, cost, 0)
		if plan.is_empty():
			failures.append("exported cost-first conversion planner returned no plan")
		else:
			for step in plan:
				if step[0] != null and probe.tap_for_mana(0, step[0], step[1]) != "":
					failures.append("exported mana conversion activation failed")
			if not probe.players[0].mana_pool.can_pay(cost):
				failures.append("exported conversion did not produce two black mana")
	Settings.set_value("enabled_card_packs", before, false)
	CardPacks._configure_registry()
	if failures.is_empty():
		print("PACK 2 EXPORT VERIFY OK — 999 identities, 102 Fallen Empires scripts, 204 decoded art files, 7 crown/medallion textures, executable mana conversion")
		get_tree().quit(0)
	else:
		for why in failures:
			printerr("PACK 2 EXPORT VERIFY FAILED: " + why)
		get_tree().quit(2)


## Packaging integration, not a claim that all card interactions passed.
## Pending rules are counted explicitly so a resource-only pass cannot hide
## an unfinished card. Never saves the temporary enabled-pack selection.
func _verify_exported_pack_3() -> void:
	var before := Settings.enabled_card_packs()
	var failures: Array[String] = []
	var pending := 0
	var art_count := 0
	if not CardPacks.has_pack(IceAgePack.ID):
		failures.append("the exact Pack 3 ZIP was not discovered or validated")
	else:
		Settings.set_value("enabled_card_packs", [IceAgePack.ID], false)
		CardPacks._configure_registry()
		CardRegistry.ensure_loaded()
		if CardRegistry.size() != 1243 or CardRegistry.names_in_set("ice").size() != 373:
			failures.append("expected 1,243 identities including 373 Ice Age names")
		for name in IceAgePack.names():
			if not CardRegistry.has_card(name):
				failures.append("missing card: " + name)
				continue
			var card := CardRegistry.get_card(name)
			if card.cast_condition.is_valid() and card.cast_condition.get_method() == "_pending": pending += 1
			for full in [false, true]:
				var path := CardPacks.art_path(name, "ice", full)
				var picture := Image.load_from_file(path) if path != "" else null
				if picture == null or picture.is_empty(): failures.append("missing or unreadable Ice Age artwork: " + name)
				else: art_count += 1
		for row in IceAgePack.scripts():
			if not ResourceLoader.exists(String(row.path)) or load(String(row.path)) == null:
				failures.append("missing dormant script: " + String(row.name))
		if pending > 0: failures.append("unfinished Ice Age rules: %d" % pending)
		for key in ["set_icon_ice", "filter_ice_on", "filter_ice_off"]:
			var symbol := GameSkin.our_art(key)
			if symbol == null or symbol.get_image().is_empty(): failures.append("missing Ice Age UI texture: " + key)
		var ghoul := CardRegistry.get_card("Ashen Ghoul")
		if ghoul == null or ghoul.activated_abilities.is_empty() or ghoul.activated_abilities[0].activation_zone != Mtg.Zone.GRAVEYARD:
			failures.append("exported graveyard ability did not load")
		var probe := MtgGame.new()
		probe.setup(["Forest", "Forest"], ["Forest", "Forest"])
		probe.start(0)
		var elf := CardInstance.new(CardRegistry.get_card("Adarkar Unicorn"), probe._next_instance_id, 0)
		probe._next_instance_id += 1
		probe._instances[elf.id] = elf
		probe._put_on_battlefield(elf, 0)
		elf.summoning_sick = false
		if probe.tap_for_mana(0, elf, 1) != "" or not probe.players[0].mana_pool.can_pay(ManaCost.parse("{1}{U}"), 0, ["cumulative_upkeep"]):
			failures.append("exported coupled restricted-mana ability failed")
		if probe.players[0].mana_pool.can_pay(ManaCost.parse("{1}{U}")):
			failures.append("exported restriction incorrectly paid an unrestricted cost")
	Settings.set_value("enabled_card_packs", before, false)
	CardPacks._configure_registry()
	if failures.is_empty():
		print("PACK 3 EXPORT RESOURCES OK — 1,243 identities, 373 Ice Age names, 346 dormant scripts, %d decoded artwork files, 3 UI textures; %d rules still pending" % [art_count, pending])
		get_tree().quit(0)
	else:
		for why in failures: printerr("PACK 3 EXPORT VERIFY FAILED: " + why)
		get_tree().quit(2)


## Real external ZIP and trusted dormant rules in an actual exported binary.
func _verify_exported_pack_4() -> void:
	var before := Settings.enabled_card_packs()
	var failures: Array[String] = []
	var art_count := 0
	if not CardPacks.has_pack(HomelandsPack.ID):
		failures.append("the exact Pack 4 ZIP was not discovered or validated")
	else:
		Settings.set_value("enabled_card_packs", [HomelandsPack.ID], false)
		CardPacks._configure_registry()
		CardRegistry.ensure_loaded()
		if CardRegistry.size() != 1012 or CardRegistry.names_in_set("hml").size() != 115:
			failures.append("expected 1,012 identities including 115 Homelands names")
		for name in HomelandsPack.names():
			var card := CardRegistry.get_card(name)
			if card == null:
				failures.append("missing card: " + name)
				continue
			if card.cast_condition.is_valid() and card.cast_condition.get_method() == "_pending": failures.append("unfinished rules: " + name)
			for full in [false, true]:
				var path := CardPacks.art_path(name, "hml", full)
				var picture := Image.load_from_file(path) if path != "" else null
				if picture == null or picture.is_empty(): failures.append("missing artwork: " + name)
				else: art_count += 1
		for row in HomelandsPack.scripts():
			if not ResourceLoader.exists(String(row.path)) or load(String(row.path)) == null: failures.append("missing dormant script: " + String(row.name))
		for key in ["set_icon_hml", "filter_hml_on", "filter_hml_off"]:
			var symbol := GameSkin.our_art(key)
			if symbol == null or symbol.get_image().is_empty(): failures.append("missing UI texture: " + key)
		var abbot := CardRegistry.get_card("Hazduhr the Abbot")
		if abbot == null or not abbot.activated_abilities[0].effects[0] is CreatureRedirectEffect: failures.append("typed damage-redirection effect failed to load")
		var oyster := CardRegistry.get_card("Giant Oyster")
		if oyster == null or oyster.activated_abilities[0].effects[0].ai_role != &"sustained_lock": failures.append("public AI effect metadata failed to load")
	Settings.set_value("enabled_card_packs", before, false)
	CardPacks._configure_registry()
	if failures.is_empty():
		print("PACK 4 EXPORT RESOURCES OK — 1,012 identities, 115 Homelands names/dormant scripts, %d decoded artwork files, 3 UI textures; zero pending rules" % art_count)
		get_tree().quit(0)
	else:
		for why in failures: printerr("PACK 4 EXPORT VERIFY FAILED: " + why)
		get_tree().quit(2)


func _verify_exported_pack_5() -> void:
	var before := Settings.enabled_card_packs()
	var failures: Array[String] = []
	var art_count := 0
	if not CardPacks.has_pack(AlliancesPack.ID):
		failures.append("the exact Pack 5 ZIP was not discovered or validated")
	else:
		Settings.set_value("enabled_card_packs", [AlliancesPack.ID], false)
		CardPacks._configure_registry()
		CardRegistry.ensure_loaded()
		if CardRegistry.size() != 1041 or CardRegistry.names_in_set("all").size() != 144:
			failures.append("expected 1,041 identities including 144 Alliances names")
		for name in AlliancesPack.names():
			var card := CardRegistry.get_card(name)
			if card == null:
				failures.append("missing card: " + name)
				continue
			if card.cast_condition.is_valid() and card.cast_condition.get_method() == "_pending": failures.append("unfinished rules: " + name)
			for full in [false, true]:
				var path := CardPacks.art_path(name, "all", full)
				var picture := Image.load_from_file(path) if path != "" else null
				if picture == null or picture.is_empty(): failures.append("missing artwork: " + name)
				else: art_count += 1
		for row in AlliancesPack.scripts():
			if not ResourceLoader.exists(String(row.path)) or load(String(row.path)) == null: failures.append("missing dormant script: " + String(row.name))
		for key in ["set_icon_all", "filter_all_on", "filter_all_off"]:
			var symbol := GameSkin.our_art(key)
			if symbol == null or symbol.get_image().is_empty(): failures.append("missing UI texture: " + key)
		var force := CardRegistry.get_card("Force of Will")
		if force == null or force.modes.size() != 2: failures.append("pitch payment modes failed to load")
		var browse := CardRegistry.get_card("Browse")
		if browse == null or browse.activated_abilities[0].effects[0].ai_role != &"library_selection": failures.append("public AI effect metadata failed to load")
	Settings.set_value("enabled_card_packs", before, false)
	CardPacks._configure_registry()
	if failures.is_empty():
		print("PACK 5 EXPORT RESOURCES OK — 1,041 identities, 144 Alliances names/dormant scripts, %d decoded artwork files, 3 UI textures; zero pending rules" % art_count)
		get_tree().quit(0)
	else:
		for why in failures: printerr("PACK 5 EXPORT VERIFY FAILED: " + why)
		get_tree().quit(2)


## One shell button, at this screen's size.
static func _menu_button(label: String) -> Button:
	return UiChrome.menu_button(label, MENU_BUTTON, MENU_FONT, MENU_BOLD)


## The shared treatment of the two corner labels (see the wordmark above).
static func _corner_label(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _open(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
