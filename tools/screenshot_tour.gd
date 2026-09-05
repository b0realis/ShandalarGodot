extends Node
## Screenshot tour — runs the real game under a display (xvfb-run for CI)
## and captures: the main menu, the coin toss, and a mid-game duel with
## both sides played by AI THROUGH the live UI. Output paths come from the
## SHANDALAR_SHOT_DIR environment variable (default user://).
##
##   xvfb-run -a ../tools/godot --path . res://tools/screenshot_tour.tscn
##
## The duel drives seat 0 by calling a helper AiPlayer directly against
## the engine (the UI refreshes via signals, exactly as if a human were
## clicking) while seat 1 runs on the DuelScreen's own AI pacing timer —
## so the captured board is genuine two-sided gameplay, not a staged mock.

var _dir := ""


func _ready() -> void:
	_dir = OS.get_environment("SHANDALAR_SHOT_DIR")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("user://")
	await _tour()
	get_tree().quit()


func _tour() -> void:
	# ---- 1. the main menu ----
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child(menu)
	await _settle(0.8)
	_capture("shot_menu.png")
	menu.queue_free()
	await _settle(0.2)

	# ---- 2. the battle-setup screen ----
	var setup: Control = load("res://game/setup_screen.tscn").instantiate()
	add_child(setup)
	await _settle(0.6)
	_capture("shot_setup.png")
	# ...and the DECK LIST open, which is the only place `<random deck>`
	# and the group headings ([DeckGroups]) can actually be read.
	setup._deck_options[0].show_popup()
	await _settle(0.5)
	_capture("shot_setup_decks.png")
	setup._deck_options[0].get_popup().hide()
	await _settle(0.2)
	# The `?` beside the format picker — the same explain popup the
	# Options screen puts beside each rules fork (item 5).
	setup._explain_formats()
	await _settle(0.4)
	_capture("shot_setup_formats.png")
	setup.queue_free()
	await _settle(0.2)

	# ---- 3. the duel: coin toss, then real play ----
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	var duel_config := DuelConfig.vs_ai_default(AiProfile.wizard())
	duel_config.player_names[0] = "White Wizard"
	# §6.19: the tour plays FOR ANTE, so the opening window has a real
	# stake to show. One card each — the original's `&Ante` checkbox.
	duel_config.ante = 1
	duel.config = duel_config
	# The tour gives the seats real names and decks, because the PRE-DUEL
	# SPLASH ([DuelIntro]) reads them and this is the shot that documents
	# it. Portraits are left unset on purpose: that is the fallback path,
	# where each seat wears its deck's own duelist face.
	duel_config.player_names[1] = "AI Wizard"
	duel_config.deck_names = ["White Knights", "Black-Red Raiders"]
	add_child(duel)
	await _settle(0.6)
	_capture("shot_duel_intro.png")
	# ...and then it is dismissed, or every shot after this one is of the
	# splash instead of the duel (it holds for five seconds).
	_dismiss_intro(duel)
	await _settle(0.5)          # the coin is still turning
	_capture("shot_coin_toss.png")
	await _settle(1.4)          # it settles on the leader's colour
	_capture("shot_coin_toss_result.png")
	# ---- 3a. THE OPENING WINDOW (§6.19): one panel on the classical
	# line-art ground, carrying the first-turn line, both antes as full
	# cards, and the window's own buttons. Captured LIVE — these are the
	# two cards the duel really staked. WAITED FOR rather than slept
	# towards: the coin turns for a variable time and a fixed settle used
	# to photograph the coin dialog fading instead.
	await _await_opening_window(duel)
	_capture("shot_opening_window.png")
	# ANSWER the play-or-draw question. It is modal and waits for a click,
	# so without this every later capture is composed UNDER it — the
	# graveyard and damage-division shots were both taken through it.
	await _answer_opening(duel)
	# ---- 3b. THE SAME WINDOW WITH THE MULLIGAN OFFER UP. A qualifying
	# hand (no land, or all land) is rare, so the composition the owner's
	# 1997 screenshot shows would otherwise never reach the review set:
	# opponent's status on the right, `Take mulligan` beside `Start the
	# duel`. Staged on a second window over the same board, then dropped.
	await _capture_mulligan_offer(duel)

	# Seat 0 plays through a helper AI against the live engine.
	var human_stand_in := AiPlayer.new(0, AiProfile.wizard())
	for _i in 60:
		if duel.game.game_over or duel.game.turn_number >= 7:
			break
		var game := duel.game
		# §1.3: the engine now HOLDS a resolution open when a card asks seat
		# 0 something. The stand-in answers it the way a player would — by
		# clicking an option — so the tour plays on.
		if game.awaiting_choice != null:
			duel._on_choice_option(0)
			await _settle(0.25)
			continue
		var our_move: bool = (game.awaiting_attackers and game.active_player == 0) \
			or (game.awaiting_blockers and game.opponent_of(game.active_player) == 0) \
			or (not game.awaiting_attackers and not game.awaiting_blockers
				and game.priority_player == 0)
		if our_move:
			human_stand_in.act(game)
		await _settle(0.35)
	await _settle(0.5)
	_capture("shot_duel.png")

	# Stacked-hand mode (Options → "Hand display"): force-show the hover
	# preview on the first strip so the review shot exercises it.
	if duel._hand_rows[1] is StackHand and not duel.game.players[0].hand.is_empty():
		var stack: StackHand = duel._hand_rows[1]
		var first: CardInstance = duel.game.players[0].hand[0]
		duel._card_preview.show_card(first)   # centers itself (undocked)
		await _settle(0.3)
		_capture("shot_duel_stack_hover.png")

	# Put a freshly-summoned creature on the table so the summoning-
	# sickness spiral is always in the review shots.
	var lion := CardRegistry.get_card("Savannah Lions")
	if lion != null:
		var fresh := CardInstance.new(lion, duel.game._next_instance_id, 0)
		duel.game._next_instance_id += 1
		duel.game._instances[fresh.id] = fresh
		duel.game._put_on_battlefield(fresh, 0)
		duel._refresh()
		await _settle(0.3)
		_capture("shot_duel_sick.png")

	# THE OWNER'S REFERENCE HAND, staged card for card: Disintegrate /
	# Fork / Regrowth / Disenchant / Volcanic Island / Taiga in a RED-deck
	# window — the exact hand in the zoomed 1997 screenshot, so the chrome
	# and the per-card ROW TINTS can be compared side by side. A mixed
	# hand is the point: the white starter deck tints every row cream and
	# hides tinting bugs.
	if duel._hand_rows[1] is StackHand:
		var stack2: StackHand = duel._hand_rows[1]
		var hand: Array = duel.game.players[0].hand
		hand.clear()
		for card_name in ["Disintegrate", "Fork", "Regrowth", "Disenchant",
				"Volcanic Island", "Taiga"]:
			var data := CardRegistry.get_card(card_name)
			if data == null:
				continue
			var inst := CardInstance.new(data, duel.game._next_instance_id, 0)
			duel.game._next_instance_id += 1
			duel.game._instances[inst.id] = inst
			inst.zone = Mtg.Zone.HAND
			hand.append(inst)
		stack2.set_deck_color("red")
		duel._refresh()
		await _settle(0.3)
		_capture("shot_hand_mixed.png")
		# ...and the same window COLLAPSED (the ▲ end of the bar).
		stack2._set_collapsed(true)
		await _settle(0.2)
		_capture("shot_hand_collapsed.png")
		stack2._set_collapsed(false)
		await _settle(0.2)

	# ---- ARRANGE CARDS (docs/duel-todo.md §2.3) ----
	# The toggle in the sidebar's QoL reserve, shot both ways over the SAME
	# board, so the two captures can be diffed. The board is staged messy
	# on purpose — duplicate lands half of them tapped, creatures out of
	# size order — because an already-tidy table proves nothing.
	for scatter in ["Mountain", "Forest", "Mountain", "Badlands", "Forest"]:
		var land := _summon(duel, scatter, 0)
		if land != null:
			land.tapped = land.data.card_name == "Mountain"
	for beast in ["Grizzly Bears", "Shivan Dragon", "Wall of Stone",
			"Hill Giant"]:
		_summon(duel, beast, 0)
	duel.game.recalculate()
	duel._refresh()
	await _settle(0.3)
	_capture("shot_arrange_off.png")
	duel._arrange_button.button_pressed = true
	await _settle(0.4)
	_capture("shot_arrange_on.png")
	duel._arrange_button.button_pressed = false
	await _settle(0.2)

	# ---- THE DUELIST'S FACE (docs/duel-todo.md §6.5) ----
	# The life register's two sides, over the same board so they can be
	# diffed: the wallpaper with the life total, then the colour's own
	# duelist with no number — `Duel.hlp`, topic "Duelist's Face". Both
	# registers are turned so the capture carries both colours at once,
	# and the mini-menu that turns them (`@MENU_FACE`) is shot open.
	duel._face_flipped = [true, true]
	duel._refresh()
	await _settle(0.4)
	_capture("shot_duelist_face.png")
	duel._open_life_menu(0, Vector2(150, 640))
	await _settle(0.4)
	_capture("shot_menu_face.png")
	duel._life_menu.hide()
	duel._face_flipped = [false, false]
	duel._refresh()
	await _settle(0.3)
	# ...and the same mini-menu with the registers the OTHER way up, which
	# is the only place `@MENU_LIFE`'s `Flip over to face` is readable.
	duel._open_life_menu(0, Vector2(150, 640))
	await _settle(0.4)
	_capture("shot_menu_life.png")
	duel._life_menu.hide()
	await _settle(0.2)

	# ---- the TERRITORY menu (@MENU_TERRITORY, §6.3) ----
	# The `Go to:` list, which is the half of the original's fast-forward
	# that Run to did not cover, plus the rest of the table greyed.
	duel._open_territory_menu(0, Vector2(430, 300))
	await _settle(0.4)
	_capture("shot_menu_territory.png")
	duel._territory_menu.hide()
	await _settle(0.2)

	# ---- the SITUATION BAR's two buttons (§6.11) ----
	# `Duel.hlp`: "a Done button, a Cancel button, or both, depending on
	# the situation". Both is the rarer frame and the one that was missing,
	# so it is the one that gets a capture: mid-cast, one target already
	# picked and takeable back (§3.1), Cancel showing beside Done.
	var pyro := CardRegistry.get_card("Pyrotechnics")
	if pyro != null:
		var shot_spell := CardInstance.new(pyro, duel.game._next_instance_id, 0)
		duel.game._next_instance_id += 1
		duel.game._instances[shot_spell.id] = shot_spell
		shot_spell.zone = Mtg.Zone.HAND
		duel.game.players[0].hand.append(shot_spell)
		duel._click_hand_card(shot_spell)
		var aim := _summon(duel, "Craw Wurm", 1)
		if aim != null:
			duel.game.recalculate()
			duel._on_card_clicked(aim)
		duel._refresh()
		await _settle(0.4)
		_capture("shot_bar_cancel.png")
		duel._on_escape()
		duel._on_escape()
		duel.game.players[0].hand.erase(shot_spell)
		duel._refresh()
		await _settle(0.2)

	# ---- the ARROWS (game/duel/target_arrows.gd, ported from s30) ----
	# Two staged moments, because neither shows up reliably in ordinary
	# play within seven turns: a combat with blocks assigned (RED arrows,
	# blocker top-centre → attacker bottom-centre) and a spell on the stack
	# aimed at a creature AND at a player (AMBER arrows).
	var brute := _summon(duel, "Hill Giant", 1)
	var wall := _summon(duel, "Wall of Stone", 0)
	var was_active: int = duel.game.active_player
	if brute != null and wall != null:
		# Stand the duel in the DECLARE BLOCKERS step, which is what puts
		# the COMBAT BAR up in place of the Phase Bar and opens the COMBAT
		# WINDOW (combat_bar.gd / combat_window.gd). The opponent (seat 1)
		# is the attacker here, so the window's title reads "<name> Attack"
		# and their lineup takes the TOP lane.
		duel.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
		duel.game.active_player = 1
		duel.game.awaiting_blockers = true
		duel.game.combat.attackers[brute.id] = true
		duel.mode = DuelScreen.Mode.BLOCKERS
		duel._block_map = {wall.id: brute.id}
		duel._refresh()
		await _settle(0.4)
		_capture("shot_duel_block_arrows.png")
		_capture("shot_combat_window.png")
		# ...and the same moment MINIMISED: the window folds into the
		# dagger icon in the Phase Bar's centre band (manual p.126), and
		# the lineup drops back onto the board.
		duel._on_combat_minimized(true)
		await _settle(0.3)
		_capture("shot_combat_minimized.png")
		duel._on_window_icon_pressed()
		await _settle(0.2)
		# The player's OWN attack: the Combat Bar turns blue and the
		# attackers take the bottom lane ("Your attack").
		duel.game.awaiting_blockers = false
		duel.game.combat.clear()
		duel.mode = DuelScreen.Mode.NORMAL
		duel._block_map = {}
		var mine := _summon(duel, "Serra Angel", 0)
		var theirs := _summon(duel, "Craw Wurm", 1)
		if mine != null and theirs != null:
			duel.game._step_index = Mtg.STEP_ORDER.find(
				Mtg.Step.DECLARE_ATTACKERS)
			duel.game.awaiting_attackers = true
			duel.game.active_player = 0
			duel.mode = DuelScreen.Mode.ATTACKERS
			duel._selected_attackers = [mine.id]
			duel._refresh()
			await _settle(0.4)
			_capture("shot_combat_your_attack.png")
			duel._selected_attackers = []
			duel.game.awaiting_attackers = false
		# Out of combat again — post-combat main, the sub-phase the Combat
		# Bar's own exit icon points at — so the rest of the tour is shot
		# with the ordinary PHASE BAR back in the column.
		duel.mode = DuelScreen.Mode.NORMAL
		duel.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN2)
		duel.game.active_player = was_active
		duel.game.combat.clear()
		duel._refresh()

	# ---- STOPS and the phase mini-menu (docs/duel-todo.md §6.1) ----
	# Two red dots at once, on BOTH halves of the bar — the opponent's Main
	# pre-combat ("A Stop on your opponent's Main Pre-Combat sub-phase is
	# always a good idea", `Duel.hlp`) and your own post-combat Main — plus
	# the @MENU_PHASEBAR mini-menu open over a third icon.
	if duel._phase_bar != null:
		duel.stops.set_marked(PhaseStops.Half.OPPONENTS,
			PhaseStops.Bar.PHASE, 3, true)
		duel.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE,
			5, true)
		duel._refresh()
		await _settle(0.3)
		_capture("shot_phase_stops.png")
		# Opened over the icon that IS marked, so the capture shows the tick
		# on "Mark this phase to always stop" — the only un-mark affordance
		# the 1997 string table leaves room for.
		duel._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 5,
			duel._phase_bar.get_global_rect().position + Vector2(46, 630))
		await _settle(0.4)
		_capture("shot_menu_phasebar.png")
		duel._phase_menu.hide()
		# Leave nothing in the player's settings file: the tour marks these
		# for the camera only.
		duel.stops.clear_all()
		Settings.clear_value(PhaseStops.SETTING_KEY)
		duel._refresh()
		await _settle(0.2)

	var bolt_data := CardRegistry.get_card("Lightning Bolt")
	if bolt_data != null and brute != null:
		var bolt := CardInstance.new(bolt_data, duel.game._next_instance_id, 0)
		duel.game._next_instance_id += 1
		duel.game._instances[bolt.id] = bolt
		var item := StackItem.new()
		item.kind = Mtg.StackKind.SPELL
		item.controller = 0
		item.card = bolt
		item.description = "Lightning Bolt"
		# One arrow to a creature, one to the opponent themself — the life
		# panel must be a legal arrow terminus (s30's targetPosition).
		item.targets = [TargetRef.card(brute), TargetRef.player(1)]
		duel.game.stack.append(item)
		duel._refresh()
		await _settle(0.4)
		_capture("shot_duel_stack_arrows.png")

		# ---- the SPELL CHAIN, three deep (forty-second pass) ----
		# `Duel.hlp`, **Spell Chain**: *"A group of spells played in
		# response to one another is called a batch or spell chain… all
		# batches are displayed in the Spell Chain window."* One spell, an
		# ABILITY activated in response to it, and an X spell on top —
		# which is the case that measures the strip, since every chain
		# object is now a full-size MiniCard and X rides on the caption.
		var sorcerer := _summon(duel, "Prodigal Sorcerer", 1)
		if sorcerer != null:
			var zap := StackItem.new()
			zap.kind = Mtg.StackKind.ABILITY
			zap.controller = 1
			zap.card = sorcerer
			zap.description = "Prodigal Sorcerer: 1 damage"
			if wall != null:
				var zap_targets: Array[TargetRef] = [TargetRef.card(wall)]
				zap.targets = zap_targets
			duel.game.stack.append(zap)
		var fireball_data := CardRegistry.get_card("Fireball")
		if fireball_data != null:
			var fireball := CardInstance.new(fireball_data,
				duel.game._next_instance_id, 0)
			duel.game._next_instance_id += 1
			duel.game._instances[fireball.id] = fireball
			var big := StackItem.new()
			big.kind = Mtg.StackKind.SPELL
			big.controller = 0
			big.card = fireball
			big.x_value = 3
			big.description = "Fireball (X is 3)"
			var big_targets: Array[TargetRef] = [TargetRef.card(brute)]
			big.targets = big_targets
			duel.game.stack.append(big)
		duel._refresh()
		await _settle(0.4)
		_capture("shot_duel_spell_chain.png")
		duel.game.stack.clear()
		if sorcerer != null:
			# It was summoned for this one frame; the board the rest of the
			# tour photographs is the one the AI actually played.
			duel.game.players[1].battlefield.erase(sorcerer)
		duel._refresh()

	# ---- the 1997 POPUPS (game/duel/original_dialog.gd) ----
	# Every centre dialog wears the same chrome, so every one of them is
	# captured: the modal-choice dialog, the X question, the library
	# picker and the end-of-duel window. None of these reaches the screen
	# in ordinary play inside a tour, so each is opened directly.
	# Healing Salve is the engine's reference MODAL spell (CardData.modes),
	# so it is the one that actually fills the choice column.
	var salve := CardRegistry.get_card("Healing Salve")
	if salve != null:
		var clay_inst := CardInstance.new(salve, 99001, 0)
		duel.game._instances[clay_inst.id] = clay_inst
		duel._pending_card = clay_inst
		duel._pending_pid = 0
		duel._open_mode_menu(clay_inst)
		await _settle(0.4)
		_capture("shot_dialog_modes.png")
		duel._close_mode_overlay()
		duel._pending_card = null

	var fireball := CardRegistry.get_card("Fireball")
	if fireball != null:
		var fb := CardInstance.new(fireball, 99002, 0)
		duel.game._instances[fb.id] = fb
		duel._pending_card = fb
		duel._pending_pid = 0
		duel._pending_ability_index = -1
		duel._open_x_dialog()
		await _settle(0.4)
		_capture("shot_dialog_x.png")
		duel._x_dialog.queue_free()
		duel._x_dialog = null
		duel._pending_card = null

	# THE DUEL OPTIONS PANEL (§6.4) — `@DIALOG_DUELOPTIONS`'s nineteen
	# strings, opened the way the 1997 player opened it: `Duel Options...`
	# on the territory mini-menu.
	duel._open_duel_options()
	await _settle(0.4)
	_capture("shot_duel_options.png")
	if duel._options_dialog != null:
		duel._options_dialog.dismiss()
		duel._options_dialog = null
	await _settle(0.1)

	var tutor := CardRegistry.get_card("Demonic Tutor")
	if tutor != null:
		var dt := CardInstance.new(tutor, 99003, 0)
		duel.game._instances[dt.id] = dt
		duel._pending_card = dt
		duel._pending_pid = 0
		var search := SearchLibraryEffect.new()
		duel._open_search_dialog(search)
		await _settle(0.4)
		_capture("shot_dialog_search.png")
		duel._search_dialog.queue_free()
		duel._search_dialog = null
		duel._pending_card = null

	# The ability MINI-MENU (the original's word, manual p.116) — the one
	# popup that opens at the pointer instead of the centre of the table.
	var candela := _summon(duel, "Llanowar Elves", 0)
	if candela != null:
		duel._open_ability_menu(candela)
		duel._ability_menu.position = Vector2i(520, 360)
		await _settle(0.4)
		_capture("shot_menu_abilities.png")
		duel._ability_menu.hide()

	# ---- the four moments the duel now stops for the player ----
	# docs/duel-todo.md §1.1 (the discard phase), §1.2 (the graveyard),
	# §1.3 (the choice overlay) and §1.4 (the damage division).

	# §1.2 THE GRAVEYARD, laid out and clickable at last — and since the
	# thirty-third pass a SHELF OF FIVE mini cards at their TRUE size, with
	# ◀ ▶ arrows and the centre card's position ([QoL]). Staged LONG and
	# MIXED on purpose: paging, the counter and the three zones only show
	# themselves on a pile that overflows.
	var boneyard := ["Grizzly Bears", "Hill Giant", "Lightning Bolt",
		"Savannah Lions", "Mons's Goblin Raiders", "Air Elemental",
		"Black Knight", "Birds of Paradise", "Bog Wraith", "Black Lotus",
		"Black Vise", "Armageddon", "Bad Moon", "Badlands", "Braingeyser",
		"Castle", "Clockwork Beast", "Cockatrice", "Conservator", "Clone",
		"Mountain", "Forest", "Island", "Plains", "Swamp",
		"Basalt Monolith", "Berserk", "Benalish Hero", "Blaze of Glory",
		"Animate Wall", "Ankh of Mishra", "Aspect of Wolf", "Burrowing",
		"Camouflage"]
	for dead_name in boneyard:
		_inter(duel, 0, Mtg.Zone.GRAVEYARD, dead_name)
	# The opponent's pile, so both halves of `@CUECARD_OTHER`'s wording show.
	for dead_name in ["Serra Angel", "Disenchant", "Wrath of God", "Counterspell"]:
		_inter(duel, 1, Mtg.Zone.GRAVEYARD, dead_name)
	# `@MENU_GRAVEYARD`'s other two views, in the same overlay.
	for gone_name in ["Swords to Plowshares", "Fireball", "Healing Salve"]:
		_inter(duel, 0, Mtg.Zone.EXILE, gone_name)
	_inter(duel, 0, Mtg.Zone.ANTE, "Shivan Dragon")
	_inter(duel, 1, Mtg.Zone.ANTE, "Time Walk")
	duel._refresh()
	duel._on_grave_pile_clicked(0)
	await _settle(0.4)
	_capture("shot_graveyard_view.png")
	# Two presses of ▶: the shelf walks the pile and the counter follows.
	if duel._grave_view != null:
		duel._grave_view.step(Mtg.Zone.GRAVEYARD, 0, 1)
		duel._grave_view.step(Mtg.Zone.GRAVEYARD, 0, 1)
	await _settle(0.4)
	_capture("shot_graveyard_paged.png")
	duel._close_graveyard()
	await _settle(0.2)

	# THE EXILE PILE, right of the graveyard: seat 0's holds the three cards
	# staged above (so it shows its top card), seat 1's is empty (so it shows
	# the derived plate) — both states of the pile in one frame.
	duel._refresh()
	await _settle(0.3)
	_capture("shot_exile_pile.png")

	# The same view while TARGETING: Raise Dead is on the pointer, the pile
	# opens on the page holding the first card it can legally take, and
	# that card wears the board's own yellow target frame.
	var raise := CardRegistry.get_card("Raise Dead")
	if raise != null:
		var spell := CardInstance.new(raise, duel.game._next_instance_id, 0)
		duel.game._next_instance_id += 1
		duel.game._instances[spell.id] = spell
		spell.zone = Mtg.Zone.HAND
		duel.game.players[0].hand.append(spell)
		duel.game.active_player = 0
		duel.game.priority_player = 0
		duel.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
		duel.game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
		duel._click_hand_card(spell)
		duel._on_grave_pile_clicked(0)
		await _settle(0.4)
		_capture("shot_graveyard_target.png")
		duel._close_graveyard()
		duel._clear_pending()
		duel.game.players[0].hand.erase(spell)
		duel.game.players[0].mana_pool.clear()
		duel._refresh()
		await _settle(0.2)

	# §1.1 THE DISCARD PHASE — `@PROMPT_DISCARD`, "Paused: Discard phase".
	duel.game.active_player = 0
	while duel.game.players[0].hand.size() < 9:
		var filler := CardRegistry.get_card("Grizzly Bears")
		var spare := CardInstance.new(filler, duel.game._next_instance_id, 0)
		duel.game._next_instance_id += 1
		duel.game._instances[spare.id] = spare
		spare.zone = Mtg.Zone.HAND
		duel.game.players[0].hand.append(spare)
	duel.game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.CLEANUP))
	duel._refresh()
	if not duel.game.players[0].hand.is_empty():
		duel._on_card_clicked(duel.game.players[0].hand[0])
	await _settle(0.4)
	_capture("shot_discard_phase.png")
	duel.game.awaiting_discard = false
	duel.game.discard_count = 0
	duel.mode = DuelScreen.Mode.NORMAL
	duel._refresh()
	await _settle(0.2)

	# §1.3 THE CHOICE OVERLAY — the upkeep cost, put to the player the FIRST
	# time the card asks. The engine pre-flights the trigger, finds the
	# question and holds the resolution open; the overlay is the answer.
	_clear_the_table(duel)
	var rent := _stage(duel, [["Junún Efreet", 0], ["Swamp", 0], ["Swamp", 0]])
	if rent.has("Junún Efreet"):
		duel.game.active_player = 0
		duel.game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
		var spin := 0
		while duel.game.awaiting_choice == null and not duel.game.stack.is_empty() \
				and spin < 8:
			duel.game.pass_priority(duel.game.priority_player)
			spin += 1
		duel._refresh()
		await _settle(0.4)
		_capture("shot_choice_upkeep.png")
		if duel.game.awaiting_choice != null:
			duel._on_choice_option(0)     # "Pay Upkeep costs."
		await _settle(0.2)

	# ...and the same overlay carrying a CARD question: the candidates by
	# name, numbered, with the original's `Cancel.` for a legal fail to find.
	var picker := PlayerChoice.new(PlayerChoice.Kind.CARD, 0,
		"Select target card.")
	picker.source = "Demonic Tutor"
	picker.optional = true
	for wanted in ["Lightning Bolt", "Serra Angel", "Black Lotus", "Swamp"]:
		var data := CardRegistry.get_card(wanted)
		if data != null:
			picker.candidates.append(
				CardInstance.new(data, 90000 + picker.candidates.size(), 0))
	duel.game.awaiting_choice = picker
	duel._refresh()
	await _settle(0.4)
	_capture("shot_choice_card.png")
	duel.game.awaiting_choice = null
	duel._close_choice_overlay()
	duel._refresh()
	await _settle(0.2)
	_clear_the_table(duel)

	# ...and the same overlay carrying a COST question — §1.3's last four
	# rows. Metamorphosis' "as an additional cost, sacrifice a creature" is
	# paid while the spell is still IN HAND (CR 601.2h), so there is no stack
	# item for the pre-flight to probe: the engine holds the whole CAST open
	# instead and re-issues it once the body is named. Three creatures out,
	# so the choice is a real one. The words are the original's —
	# `@SACRIFICE_CREATURE`, Program/Text.res:2649-2651.
	_stage(duel, [["Grizzly Bears", 0], ["Hill Giant", 0], ["Serra Angel", 0],
		["Forest", 0]])
	var meta_data := CardRegistry.get_card("Metamorphosis")
	if meta_data != null:
		var meta := CardInstance.new(meta_data, duel.game._next_instance_id, 0)
		duel.game._next_instance_id += 1
		duel.game._instances[meta.id] = meta
		meta.zone = Mtg.Zone.HAND
		duel.game.players[0].hand.append(meta)
		duel.game.active_player = 0
		duel.game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
		duel.game.priority_player = 0
		duel.game.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
		duel.game.cast_spell(0, meta, [])
		duel._refresh()
		await _settle(0.4)
		_capture("shot_choice_sacrifice.png")
		if duel.game.awaiting_choice != null:
			duel._on_choice_option(0)
		await _settle(0.2)
		duel.game.players[0].hand.erase(meta)
		duel.game.players[0].mana_pool.clear()
	duel.game.stack.clear()
	duel._refresh()
	await _settle(0.2)
	_clear_the_table(duel)

	# §1.4 THE DAMAGE DIVISION — `%s: Assign damage to blockers, %d points
	# left`, mid-count.
	var gang_target := _summon(duel, "Hill Giant", 0)
	var wall_a := _summon(duel, "Grizzly Bears", 1)
	var wall_b := _summon(duel, "Grizzly Bears", 1)
	if gang_target != null and wall_a != null and wall_b != null:
		var dmg_game := duel.game
		gang_target.summoning_sick = false   # _summon leaves it sick
		wall_a.summoning_sick = false
		wall_b.summoning_sick = false
		dmg_game.active_player = 0
		dmg_game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
		dmg_game.declare_attackers(0, [gang_target.id])
		dmg_game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS))
		dmg_game.awaiting_blockers = true
		dmg_game.declare_blockers(1, {wall_a.id: gang_target.id, wall_b.id: gang_target.id})
		dmg_game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE))
		duel._refresh()
		duel._on_card_clicked(wall_a)
		await _settle(0.4)
		_capture("shot_damage_division.png")
		duel._confirm_damage()
		await _settle(0.2)

	# ---- THE SMALL-CARD STATES (docs/duel-todo.md §2.9/§2.10/§2.11/§6.15) --
	# `@CUECARD_SMALLCARD` names TEN states a card on the table can be in and
	# none of them turns up reliably in seven turns of play, so the board is
	# cleared and rebuilt one state at a time. THREE captures, each with a
	# board small enough to fit the play area in ONE ROW — the first staging
	# put eight creatures out and the second row fell off the bottom edge:
	#   1. the OVERLAYS  2. the BADGES  3. the same badge board, targeting.
	_clear_the_table(duel)
	var staged: Dictionary = _stage(duel, [["Craw Wurm", 0],
		["Grizzly Bears", 0], ["Serra Angel", 0], ["Hill Giant", 1]])
	# WILL UNTAP: tapped, and nothing holding it down (the inverse of a
	# Meekstone lock) — the blue arrow at the art's top-right corner.
	if staged.has("Serra Angel"):
		staged["Serra Angel"].tapped = true
	# SUMMONING SICK: the spiral, at full strength over the art.
	_summon(duel, "Shivan Dragon", 0)
	# CARD IS NOT CONTROLLED BY OWNER: seat 1's Hill Giant, taken. The one
	# state on the original's list with no art, so it is LETTERED.
	if staged.has("Hill Giant"):
		duel.game.change_control(staged["Hill Giant"], 0)
		staged["Hill Giant"].summoning_sick = false
	# PUMPED / WEAKENED P/T: a Crusade, so the s30 three-way colouring is on
	# screen — Serra Angel letters its stats GREEN, the rest stay white.
	_summon(duel, "Crusade", 0)
	duel.game.recalculate()
	# DAMAGE LAST, and after the last call that runs state-based actions: a
	# lethally damaged creature is destroyed the moment they run, so `Dying`
	# only exists in the window between marking and checking.
	#   * Craw Wurm 6/4 with three marked — the dagger and the number, and the
	#     P/T still reading its LIVE 6/4 (manual p.114: damage is a MARKER,
	#     not a subtraction). This is the capture that shows why s30's
	#     `power/(toughness - damage)` is not ours.
	#   * Grizzly Bears 2/2 with two marked — DYING, the silver cracks.
	if staged.has("Craw Wurm"):
		staged["Craw Wurm"].damage = 3
	if staged.has("Grizzly Bears"):
		staged["Grizzly Bears"].damage = 2
	duel._refresh()
	await _settle(0.4)
	_capture("shot_duel_card_states.png")

	# ---- the BADGES, and the crosshair ----
	_clear_the_table(duel)
	var badged: Dictionary = _stage(duel, [["Drudge Skeletons", 0],
		["White Knight", 0], ["Savannah Lions", 0], ["Shivan Dragon", 0],
		["Mountain", 0]])
	# PROTECTION FROM ARTIFACTS — the brown shield, cell 10. It needs an
	# Artifact Ward on a host: `cur_protection` is a COLOUR bitmask with no
	# room for a non-colour entry, so the Ward is the only way to see it.
	var ward := CardRegistry.get_card("Artifact Ward")
	if ward != null and badged.has("Savannah Lions"):
		var ward_inst := CardInstance.new(ward, duel.game._next_instance_id, 0)
		duel.game._next_instance_id += 1
		duel.game._instances[ward_inst.id] = ward_inst
		duel.game.attach_aura_from_anywhere(ward_inst, badged["Savannah Lions"], 0)
	# THE FAN, so the one-aura and many-aura cases can be read in the SAME
	# capture (forty-first pass): the Lions wear one card behind them, the
	# Dragon wears three, in three different frame colours so the step out
	# to the right and up is unmistakable.
	if badged.has("Shivan Dragon"):
		for aura_name in ["Firebreathing", "Holy Strength", "Unholy Strength"]:
			var aura_data := CardRegistry.get_card(aura_name)
			if aura_data == null:
				continue
			var aura_inst := CardInstance.new(aura_data,
				duel.game._next_instance_id, 0)
			duel.game._next_instance_id += 1
			duel.game._instances[aura_inst.id] = aura_inst
			duel.game.attach_aura_from_anywhere(aura_inst,
				badged["Shivan Dragon"], 0)
	# IS A TARGET: a live stack item aimed at the White Knight puts the 1997
	# crosshair over its art.
	if badged.has("White Knight"):
		var shot := StackItem.new()
		shot.kind = Mtg.StackKind.SPELL
		shot.controller = 0
		shot.card = badged["White Knight"]
		shot.targets = [TargetRef.card(badged["White Knight"])]
		duel.game.stack.append(shot)
	_summon(duel, "Crusade", 0)
	duel.game.recalculate()
	duel._refresh()
	await _settle(0.4)
	_capture("shot_duel_card_badges.png")

	# ...and the SAME board mid-targeting, so the two can be diffed: legal
	# targets in yellow, the one already picked in green at width 3, and
	# everything the spec refuses stamped with the orange circle-slash.
	duel.mode = DuelScreen.Mode.TARGETING
	duel._pending_card = badged.get("Drudge Skeletons")
	duel._pending_slots = [{"spec": TargetSpec.creature(), "min": 1, "max": 2,
		"divided": false}]
	duel._pending_groups = [[TargetRef.card(badged["White Knight"])]] \
		if badged.has("White Knight") else [[]]
	duel._pending_slot = 0
	# ...and the Situation Bar's own line for it (@PROMPT_TARGET's
	# "%s(%d so far, max %d)" form), so the staged shot does not carry the
	# damage division's leftover sentence.
	duel._set_prompt("Select target creature. (1 so far, max 2)")
	duel._refresh()
	await _settle(0.4)
	_capture("shot_duel_targeting_states.png")
	duel._clear_pending()
	duel.game.stack.clear()
	duel._refresh()
	await _settle(0.2)

	duel._on_game_over(0)
	await _settle(0.4)
	_capture("shot_dialog_end_duel.png")
	if duel._over_dialog != null:
		duel._over_dialog.queue_free()
		duel._over_dialog = null
	duel.game.game_over = false
	duel._pass_button.disabled = false
	duel._refresh()

	# One more: a card from a set that HAS a symbol (Unlimited has none),
	# so the big card's set-icon slot is exercised in review shots.
	var sample := CardRegistry.get_card("Moat")
	if sample != null and duel._card_preview != null:
		var inst := CardInstance.new(sample, 99999, 0)
		duel._card_preview.show_card(inst)
		await _settle(0.3)
		_capture("shot_card_detail.png")

	# ---- 4. the Help screen (main menu -> Help) ----
	# One page of the paged reference, so a review shot exercises the icon
	# rendering: the ICON PAGES are the half that can break silently when a
	# sheet's cell map moves under them. The page is FOUND BY TITLE rather
	# than by index, so inserting a page upstream cannot quietly turn this
	# into a shot of something else.
	duel.queue_free()
	await _settle(0.3)
	var help: HelpScreen = load("res://game/help/help_screen.tscn").instantiate()
	add_child(help)
	await _settle(0.5)
	var pages := HelpPages.pages()
	for i in pages.size():
		if String(pages[i]["title"]).begins_with("Icons"):
			help.go_to(i)
			break
	await _settle(0.4)
	_capture("shot_help.png")
	# ...and THE SMALL CARD's own icon page, which is where the
	# @CUECARD_SMALLCARD states are explained. Found by title for the same
	# reason as above.
	for i in pages.size():
		if String(pages[i]["title"]).contains("the small card"):
			help.go_to(i)
			break
	await _settle(0.4)
	_capture("shot_help_small_card.png")
	# ...and the DECK FORMATS pages, whose whole job is to say what the
	# five formats mean and which of them the engine actually checks.
	var shot := 0
	for i in pages.size():
		if not String(pages[i]["title"]).begins_with("Deck formats"):
			continue
		help.go_to(i)
		await _settle(0.4)
		shot += 1
		_capture("shot_help_formats_%d.png" % shot)

	help.queue_free()
	await _settle(0.3)

	# ---- THE MATCH (`&Best of:`, docs/duel-todo.md §6.20) ----
	# The between-duels window and the Sideboard... window, which are only
	# reachable after a duel of a match ends — so the duel is ENDED here
	# rather than played out, which is exactly what MatchScreen listens for.
	var run: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	var match_config := DuelConfig.vs_ai_default(AiProfile.wizard())
	var knights := DeckList.load_file("res://decks/white_knights.deck", true)
	match_config.decks[0] = knights.cards.duplicate()
	match_config.sideboards[0] = knights.sideboard.duplicate()
	match_config.apply_deck_colors()
	match_config.best_of = 3
	match_config.sideboard_between_duels = true
	match_config.rng_seed = 4242
	run.config = match_config
	add_child(run)
	# The duel of a match opens exactly like any other duel — coin toss,
	# then the play-or-draw question — so both are answered before the
	# duel is ENDED and the match's own window takes over.
	await _await_opening_window(run._duel)
	await _answer_opening(run._duel)
	run._duel.duel_finished.emit(1)
	await _settle(0.6)
	_capture("shot_match_between_duels.png")
	run._open_sideboard(0)
	await _settle(0.5)
	_capture("shot_match_sideboard.png")
	run.queue_free()
	await _settle(0.3)

	print("screenshot tour complete -> %s" % _dir)


## Send every permanent home, for a staged capture that needs a clean
## table. Two things this has to do that are not obvious, both learned by
## breaking the tour:
##   1. Emptying `players[pid].battlefield` is NOT enough on its own —
##      statics are gathered from instances that still SAY they are on the
##      battlefield, so a Crusade the AI played kept pumping from nowhere.
##   2. **Attachments must be cut.** Leaving an aura in the graveyard still
##      pointing at a host (or a host still listing an aura) HANGS the next
##      `check_state_based_actions()`: the aura-legality rule keeps finding
##      something to fix and never reaches a fixed point. The tour sat
##      there forever until this loop was added.
func _clear_the_table(duel: DuelScreen) -> void:
	for pid in 2:
		for gone in duel.game.players[pid].battlefield:
			gone.zone = Mtg.Zone.GRAVEYARD
			gone.attached_to = -1
			gone.attachments.clear()
			gone.damage = 0
			gone.tapped = false
			duel.game.players[pid].graveyard.append(gone)
		duel.game.players[pid].battlefield.clear()
	duel.game.stack.clear()
	duel.game.combat.clear()
	# AND PUT THE SCREEN BACK IN NORMAL MODE. The earlier staged damage
	# division leaves `awaiting_damage_assignment` set, and `_refresh` flips
	# the screen straight back into Mode.DAMAGE from any mode it is put in —
	# which silently swallowed the whole TARGETING capture until the debug
	# print showed `mode=5`, not the 1 that had just been assigned.
	duel.game.awaiting_damage_assignment = false
	duel.game.awaiting_discard = false
	duel.mode = DuelScreen.Mode.NORMAL


## Put a list of [card name, seat] pairs onto the table, awake, and return
## them by name.
func _stage(duel: DuelScreen, wanted: Array) -> Dictionary:
	var out: Dictionary = {}
	for pair in wanted:
		var made := _summon(duel, pair[0], pair[1])
		if made != null:
			made.summoning_sick = false
			out[pair[0]] = made
	return out


## Drop a real card straight onto a seat's battlefield, so a staged shot
## can show a board state ordinary play would take many turns to reach.
func _summon(duel: DuelScreen, card_name: String, pid: int) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	if data == null:
		return null
	var inst := CardInstance.new(data, duel.game._next_instance_id, pid)
	duel.game._next_instance_id += 1
	duel.game._instances[inst.id] = inst
	duel.game._put_on_battlefield(inst, pid)
	return inst


## Put a real card straight into one of the three piles `@MENU_GRAVEYARD`
## shows — the graveyard, exile or ante. Named cards that are not in the
## pool are skipped, so the tour never depends on the registry's contents.
func _inter(duel: DuelScreen, pid: int, zone: int,
		card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	if data == null:
		return null
	var inst := CardInstance.new(data, duel.game._next_instance_id, pid)
	duel.game._next_instance_id += 1
	duel.game._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.EXILE: duel.game.players[pid].exile.append(inst)
		Mtg.Zone.ANTE: duel.game.players[pid].ante.append(inst)
		_: duel.game.players[pid].graveyard.append(inst)
	return inst


## Click through OpeningHand's modal questions (play-or-draw, then any
## mulligan offer) so the staged captures that follow show the BOARD and
## not a dialog. Presses the first choice each time; the tour is about
## how things look, not which branch is taken.
##
## IT WAITS FOR THE FIRST DIALOG rather than assuming it is already up.
## The coin turns for CoinToss.TURN * CoinToss.HALF_TURNS seconds and the
## play-or-draw question follows it, so on a loaded machine the fixed
## settles above can land BEFORE the question exists — and this used to
## return on that first miss, leaving the modal up for the whole rest of
## the tour. Every capture after it was then a photograph of the dialog
## over an empty turn-1 board, and nothing said so: the tour still
## finished with zero script errors.
func _answer_opening(duel: DuelScreen) -> void:
	var answered := 0
	for _round in 20:
		var button := _find_button(duel, [
			OpeningHand.PLAY_OR_DRAW["play_first"],
			OpeningHand.MULLIGAN["start"],   # "Start the duel" — keep the hand
		])
		if button != null:
			button.pressed.emit()
			answered += 1
			await _settle(0.35)
			continue
		if answered > 0:
			return          # the run of questions is over
		await _settle(0.3)  # not up yet — the coin is still turning
	push_warning("screenshot tour: the opening dialogs never appeared")


## Wait for the opening window to actually be up. The coin toss animates
## for a variable time and then fades, so a fixed settle can photograph the
## fade instead of the window behind it.
func _await_opening_window(duel: DuelScreen) -> OpeningWindow:
	for _round in 40:
		var found := duel.find_child("OpeningWindow", true, false)
		if found != null and (found as Control).is_visible_in_tree():
			await _settle(0.4)     # let the coin panel finish fading out
			return found
		await _settle(0.15)
	push_warning("screenshot tour: the opening window never appeared")
	return null


## The opening window in the state the owner's 1997 screenshot froze:
## `You will take the first turn` on the left, the opponent's mulligan on
## the right, both antes as full cards, and both buttons live. A real duel
## reaches it only when a hand has no land or all land, so the tour stages
## it rather than waiting for the shuffle to oblige.
func _capture_mulligan_offer(duel: DuelScreen) -> void:
	var window := OpeningWindow.new()
	duel.add_child(window)
	window.show_antes(duel.game, 0)
	window.set_lead(OpeningHand.MULLIGAN["you_start"])
	window.set_status(OpeningHand.MULLIGAN["no_land"]
		% duel.game.players[1].player_name)
	# Not awaited: ask() puts the button row up and then simply waits, and
	# the wait ends by itself when the window leaves the tree.
	window.ask([
		{"answer": OpeningWindow.Answer.TAKE_MULLIGAN,
			"label": OpeningHand.MULLIGAN["take"]},
		{"answer": OpeningWindow.Answer.START,
			"label": OpeningHand.MULLIGAN["start"]},
	])
	await _settle(0.4)
	_capture("shot_opening_mulligan.png")
	duel.remove_child(window)
	window.queue_free()
	await _settle(0.2)


## First Button under [param root] whose text matches any of [param labels].
func _find_button(root: Node, labels: Array) -> Button:
	if root is Button and labels.has((root as Button).text):
		return root
	for child in root.get_children():
		var found := _find_button(child, labels)
		if found != null:
			return found
	return null


## Press `Go!` on the pre-duel splash, if one is up.
func _dismiss_intro(duel: DuelScreen) -> void:
	for node in duel.find_children("*", "DuelIntro", true, false):
		(node as DuelIntro).go_pressed.emit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _capture(filename: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(filename)
	image.save_png(path)
	print("captured %s" % path)
