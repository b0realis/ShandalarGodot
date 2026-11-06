extends "res://tools/pack_9_ui_soak.gd"
## The Urza block (Pack 10) through the LIVE duel screen: the same
## DuelScreen and the same human-seat fuzzer as the base soak
## (tools/duel_soak.gd) with the Pack 9 soak's payment-row and
## special-action gestures (tools/pack_9_ui_soak.gd), and decks built
## around the block's new choice flows — echo's pay-or-sacrifice question,
## cycling from the hand's own menu (Cast or Cycling {2}, Play or Cycling
## for a cycling land), "untap up to N lands" (how many, then which),
## Metalworker's reveal-any-number, Show and Tell's picks, Storage Matrix's
## kind each untap step, Damping Engine's "sacrifice a permanent to ignore
## it", Defensive Formation's damage division by the defender, Serra's
## Hymn's verse-divided prevention, Yawgmoth's Will's plays from the
## graveyard and Temporal Aperture's play from the library's top — played
## whole, by both seats, under either rules profile.
##
## The human seat's fuzzer is the Pack 9 one with six more gestures, each
## through the screen's own handlers and only where a player's hand could
## reach: the hand card's own menu (opened by a click on a card with an
## ability that works from the hand) is answered with any item it does not
## grey; now and then a cycling card is cycled from that menu or from the
## card's right-click menu; a card the graveyard view would ring under
## Yawgmoth's Will is played from the opened graveyard; the library's
## revealed top is played from the pile while Temporal Aperture allows it;
## a Serra's Hymn with two verses or more is sacrificed from its ability
## menu (until then the seat plays from its hand alone, since the base
## gesture would sacrifice the Hymn with nothing to divide); and under its
## own Defensive Formation the seat keeps its creatures home on one turn in
## two and now and then gang-blocks one attacker, whose damage it then
## divides. Each gesture is counted only
## when the screen took it up (the card left its zone, or its cast or
## activation is pending).
##
## Requires the real local Pack-10-Urza-Block.zip and the isolated
## shandalar_test profile (tools/runtime.sh `shandalar_test_profile`); writes
## no player settings and no Elo.
##
##   . tools/runtime.sh; shandalar_find_godot; shandalar_find_timeout
##   shandalar_test_profile
##   export SHANDALAR_PACK_10="$PWD/../shandalar-packs/Pack-10-Urza-Block.zip"
##   xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 1500 "$GODOT" --path . \
##       -s res://tools/pack_10_ui_soak.gd -- --rules modern --count 5 --mode both --pace 0
##   (repeat with --rules fifth)

## Each deck: its name, its lands, nine spells at four copies each.
const URZA_SPECS := [
	["Urza Echo", {"Mountain": 12, "Forest": 12}, [
		"Goblin War Buggy", "Albino Troll", "Pouncing Jaguar", "Viashino Outrider",
		"Avalanche Riders", "Rancor", "Okk", "Outmaneuver", "Arc Lightning"]],
	["Urza Blue", {"Island": 20, "Remote Isle": 4}, [
		"Snap", "Frantic Search", "Cloud of Faeries", "Show and Tell", "Peregrine Drake",
		"Miscalculation", "Rescind", "Pendrell Drake", "Temporal Aperture"]],
	["Urza Artifacts", {"Island": 12, "Swamp": 12}, [
		"Metalworker", "Storage Matrix", "Damping Engine", "Grim Monolith",
		"Voltaic Key", "Thran Dynamo", "Thran War Machine", "Masticore", "Fluctuator"]],
	["Urza White", {"Plains": 20, "Drifting Meadow": 4}, [
		"Defensive Formation", "Serra's Hymn", "Serra Zealot", "Pegasus Charger",
		"Mother of Runes", "Glorious Anthem", "Serra's Liturgy", "Disciple of Law",
		"Opal Gargoyle"]],
	["Urza Black", {"Swamp": 20, "Polluted Mire": 4}, [
		"Yawgmoth's Will", "Exhume", "Unearth", "Phyrexian Ghoul", "Skittering Skirge",
		"Bone Shredder", "Expunge", "Duress", "Dark Ritual"]],
]


func _configure_decks(config: DuelConfig, _first: String, _second: String) -> void:
	if not OS.has_feature("shandalar_test"):
		push_error("Pack 10 UI soak requires the isolated shandalar_test profile")
		quit(3)
		return
	Settings.set_value("enabled_card_packs", [UrzaBlockPack.ID], false)
	root.get_node("CardPacks")._configure_registry()
	CardRegistry.ensure_loaded()
	if not CardRegistry.has_card("Metalworker"):
		push_error("Pack 10 UI soak requires the real local Pack-10-Urza-Block.zip")
		quit(3)
		return
	config.decks = []
	config.player_names = []
	config.printings = [{}, {}]
	for seat in 2:
		var spec: Array = URZA_SPECS[(_index + seat) % URZA_SPECS.size()]
		var deck: Array[String] = []
		var lands: Dictionary = spec[1]
		for land in lands:
			for _n in int(lands[land]): deck.append(String(land))
		for name in spec[2]:
			if not CardRegistry.has_card(String(name)):
				push_error("Pack 10 UI soak: no card named %s" % name)
				quit(3)
				return
			for _n in 4: deck.append(String(name))
		config.decks.append(deck)
		config.player_names.append(String(spec[0]))


## The Pack 9 soak's start of a duel (which reports the finished one through
## [method _report_flows]), then the Pack 10 fuzzer in its fuzzer's place —
## the same seed, so a failure replays.
func _next() -> void:
	super._next()
	if _clicker != null and _index < _plan.size():
		var seed_value: int = _plan[_index]["seed"]
		var verbose_was := _clicker.verbose
		_clicker = UrzaClicker.new(_duel, seed_value)
		_clicker.verbose = verbose_was


## The Pack 10 flows the finished duel actually went through, read off its
## game log and its questions (both seats), and the fuzzer's own clicks:
## the evidence that the soak reached them, not only loaded them.
const URZA_FLOW_LINES := {
	"echo paid": " pays echo for ", "echo let go": " doesn't pay echo for ",
	"cycled": ": Cycling {", "Show and Tell pick": " for Show and Tell",
	"Metalworker reveal": "(Metalworker)", "Damping Engine ignored": " to ignore Damping Engine",
	"Will's graveyard opened": " may play lands and spells from their graveyard",
	"Aperture top cast": "(Temporal Aperture)", "Serra's Hymn": " activates Serra's Hymn",
}

func _report_flows() -> void:
	var game: MtgGame = _duel.game
	var counts := {}
	var human_cycles := 0
	var seat_name := game.players[0].player_name + " activates "
	for line in game.log_lines:
		if String(line).begins_with("Resolving"):
			continue   # the same object again, as it resolves
		for key in URZA_FLOW_LINES:
			if String(line).contains(String(URZA_FLOW_LINES[key])):
				if key == "cycled" and not String(line).contains(" activates "):
					continue
				counts[key] = int(counts.get(key, 0)) + 1
		if String(line).begins_with(seat_name) and String(line).contains(": Cycling {"):
			human_cycles += 1
	var questions := {"untap how many": 0, "Storage Matrix kind": 0, "Metalworker how many": 0}
	for choice: PlayerChoice in game.choice_log:
		if choice.prompt.contains(": untap how many lands?"):
			questions["untap how many"] += 1
		elif choice.source == "Storage Matrix" and choice.kind == PlayerChoice.Kind.OPTION:
			questions["Storage Matrix kind"] += 1
		elif choice.source == "Metalworker":
			questions["Metalworker how many"] += 1
	var parts := PackedStringArray()
	for key in URZA_FLOW_LINES:
		parts.append("%s %d" % [key, int(counts.get(key, 0))])
	for key in questions:
		parts.append("%s %d" % [key, int(questions[key])])
	parts.append("seat 0 cycled %d" % human_cycles)
	var step: Dictionary = _plan[_index]
	var fuzz := ""
	if _clicker is UrzaClicker:
		var c := _clicker as UrzaClicker
		var asked := PackedStringArray()
		var sources: Array = c.questions.keys()
		sources.sort()
		for source in sources:
			asked.append("%s %d" % [source if String(source) != "" else "(turn)", int(c.questions[source])])
		fuzz = ("; human seat: %d payment rows chosen, %d special actions taken, %d hand-menu items, "
			+ "%d cycles taken up, %d graveyard plays taken up, %d library-top plays taken up, %d gang blocks under Defensive Formation, "
			+ "%d damage divisions as defender, %d Serra's Hymns with verses, %d divided-target picks; "
			+ "questions answered: %s") % [
			c.rows_chosen, c.specials_taken, c.hand_menu_items, c.cycles_started,
			c.graveyard_plays, c.top_plays, c.gang_blocks, c.defender_divisions, c.hymns_started,
			c.divided_picks,
			", ".join(asked) if not asked.is_empty() else "none"]
	print("SOAK PACK 10 FLOWS %s seed %d: %s%s" % ["human" if step["human"] else "demo",
		step["seed"], ", ".join(parts), fuzz])


## [TempestClicker] with the Pack 10 gestures (see the file comment). Every
## decision is still drawn from the seeded RNG.
class UrzaClicker extends TempestClicker:
	## How often an ordinary priority window first looks for a Pack 10 play
	## (a cycle, a graveyard play, the library's top).
	const URZA_CHANCE := 0.3
	var hand_menu_items := 0
	var cycles_started := 0
	var graveyard_plays := 0
	var top_plays := 0
	var defender_divisions := 0
	var divided_picks := 0
	var gang_blocks := 0
	var hymns_started := 0
	## The human seat's held questions, by the card that asked.
	var questions := {}

	func _init(p_duel: DuelScreen, seed_value: int) -> void:
		super(p_duel, seed_value)

	func _tick_choice(choice: PlayerChoice) -> void:
		if choice.pid == SEAT:
			questions[choice.source] = int(questions.get(choice.source, 0)) + 1
		super._tick_choice(choice)

	func _tick_damage() -> void:
		if duel.game.active_player != SEAT:
			defender_divisions += 1
		super._tick_damage()

	## Under our own Defensive Formation, now and then every creature that
	## can blocks the same attacker: the gang block whose damage the
	## defender divides (the base gesture blocks one by one at random and
	## seldom gangs up).
	func _tick_blockers() -> void:
		var game: MtgGame = duel.game
		var formation := _controls(func(i: CardInstance) -> bool:
			return i.data.card_name == "Defensive Formation")
		var attackers: Array = game.combat.attackers.keys()
		if not formation or attackers.is_empty() or rng.randf() < 0.5:
			super._tick_blockers()
			return
		var attacker: CardInstance = game.find_instance(
			attackers[rng.randi_range(0, attackers.size() - 1)])
		var blockers := 0
		if attacker != null:
			for blocker in game.players[SEAT].battlefield.duplicate():
				if not blocker.is_creature() or duel._block_map.has(blocker.id) \
						or CombatState.block_illegality(game, blocker, attacker, SEAT) != "":
					continue
				duel._on_card_clicked(blocker)
				duel._on_card_clicked(attacker)
				clicks += 2
				blockers += 1
		if blockers >= 2:
			gang_blocks += 1
		duel._on_done()
		clicks += 1

	func _tick_targeting() -> void:
		if duel._pending_card != null and duel._pending_slot < duel._pending_slots.size() \
				and int(duel._pending_slots[duel._pending_slot]["divided"]) > 0:
			divided_picks += 1
		super._tick_targeting()

	func _tick_normal() -> void:
		var game: MtgGame = duel.game
		# THE HAND CARD'S OWN MENU (a card with cycling — Cast or Play, or
		# Cycling): any item it does not grey, the way a player picks one;
		# one try in eight closes it unanswered.
		var menu: PopupMenu = duel._hand_action_menu
		if menu != null and menu.visible:
			clicks += 1
			var open: Array[int] = []
			for i in menu.item_count:
				if not menu.is_item_separator(i) and not menu.is_item_disabled(i):
					open.append(menu.get_item_id(i))
			menu.hide()
			if open.is_empty() or rng.randf() < 0.125:
				duel._hand_action_inst = null
				return
			var id: int = open[rng.randi_range(0, open.size() - 1)]
			hand_menu_items += 1
			var card: CardInstance = duel._hand_action_inst
			duel._on_hand_action_chosen(id)
			if id >= DuelScreen.HAND_ACTION_ABILITY_BASE and _taken_up(card, Mtg.Zone.HAND):
				cycles_started += 1
			return
		var quiet: bool = duel._mode_overlay == null \
			and not (duel._ability_menu != null and duel._ability_menu.visible) \
			and duel.mode == DuelScreen.Mode.NORMAL and duel._pending_card == null \
			and game.priority_player == SEAT and game.awaiting_choice == null \
			and duel._search_dialog == null and duel._x_dialog == null \
			and not duel.graveyard_is_open() \
			and not (game.awaiting_attackers or game.awaiting_blockers \
				or game.awaiting_discard or game.awaiting_damage_assignment)
		if quiet and rng.randf() < URZA_CHANCE and _take_urza_play():
			return
		if quiet and _controls(func(i: CardInstance) -> bool:
				return i.data.card_name == "Serra's Hymn" and int(i.counters.get("verse", 0)) < 2):
			_tick_hand_only()
			return
		super._tick_normal()

	## Does the seat control a permanent [param test] accepts?
	func _controls(test: Callable) -> bool:
		for inst in duel.game.players[SEAT].battlefield:
			if test.call(inst):
				return true
		return false

	## While our Serra's Hymn has fewer than two verses the base gesture would
	## sacrifice it with nothing to divide (every permanent's ability is a
	## random click away there), so the seat plays from its hand alone: a
	## land first thing in its own main phase, else a card it can pay for,
	## else it passes.
	func _tick_hand_only() -> void:
		var game: MtgGame = duel.game
		clicks += 1
		var hand: Array = game.players[SEAT].hand
		var own_main := game.active_player == SEAT and Mtg.is_main_step(game.current_step()) \
			and game.stack.is_empty()
		if own_main and game.land_drop_available(SEAT):
			for inst in hand:
				if inst.is_land() and rng.randf() < 0.9:
					duel._on_card_clicked(inst)
					return
		var options: Array = []
		for inst in hand:
			if inst.is_land() or (not own_main and not inst.is_type(Mtg.CardType.INSTANT)):
				continue
			if game.can_afford_cost(SEAT, inst.data.cost):
				options.append(inst)
		if options.is_empty() or rng.randf() < 0.3:
			duel._on_pass()
			return
		var pick: CardInstance = options[rng.randi_range(0, options.size() - 1)]
		_float_mana_for(pick.data.cost, pick.data.cost.has_x)
		duel._on_card_clicked(pick)

	## Under our own Defensive Formation the seat keeps everything home on
	## one turn in two, so the attacks it then faces can be gang-blocked
	## ([method _tick_blockers]); otherwise the base declaration.
	func _tick_attackers() -> void:
		if _controls(func(i: CardInstance) -> bool: return i.data.card_name == "Defensive Formation") \
				and rng.randf() < 0.5:
			duel._on_done()
			clicks += 1
			return
		super._tick_attackers()

	## One Pack 10 play a player's hand could reach right now, chosen at
	## random among those open: cycle a card (its hand menu or its
	## right-click menu), play a card the graveyard view rings, or play the
	## library's revealed top. True when one was started.
	func _take_urza_play() -> bool:
		var game: MtgGame = duel.game
		var plays: Array = []
		for inst in game.players[SEAT].hand:
			for index in DuelScreen._hand_ability_indices(inst):
				if duel._hand_ability_refusal(inst, index) == "":
					plays.append(["cycle", inst, index])
		if not game.players[SEAT].graveyard_cast_permissions.is_empty():
			for inst in game.players[SEAT].graveyard:
				if game.can_cast_from_graveyard(SEAT, inst) or game.can_play_from_zone(SEAT, inst):
					plays.append(["graveyard", inst, -1])
			var library: Array = game.players[SEAT].library
			if not library.is_empty() and game.can_play_from_zone(SEAT, library.back()):
				plays.append(["top", library.back(), -1])
		# Serra's Hymn once its verses are worth dividing (the base gesture
		# sacrifices it at random, mostly with nothing to divide).
		for inst in game.players[SEAT].battlefield:
			if inst.data.card_name == "Serra's Hymn" and int(inst.counters.get("verse", 0)) >= 2 \
					and not inst.cur_activated_abilities.is_empty():
				plays.append(["hymn", inst, 0])
		if plays.is_empty():
			return false
		var play: Array = plays[rng.randi_range(0, plays.size() - 1)]
		var inst: CardInstance = play[1]
		clicks += 1
		match String(play[0]):
			"cycle":
				var ability: ActivatedAbility = inst.cur_activated_abilities[int(play[2])]
				_float_mana_for(ability.cost, false)
				if rng.randf() < 0.5:
					# The card's right-click menu lists the same line.
					duel._open_card_menu(inst, Vector2(400, 300))
					duel._card_menu.hide()
					duel._on_card_menu_chosen(DuelScreen.CARD_MENU_HAND_ABILITY_BASE + int(play[2]))
				else:
					duel._open_hand_action_menu(inst)
					duel._hand_action_menu.hide()
					duel._on_hand_action_chosen(DuelScreen.HAND_ACTION_ABILITY_BASE + int(play[2]))
				if _taken_up(inst, Mtg.Zone.HAND):
					cycles_started += 1
			"graveyard":
				if not inst.is_land():
					_float_mana_for(inst.data.cost, inst.data.cost.has_x)
				duel._on_grave_pile_clicked(SEAT)
				duel._on_graveyard_card(inst)
				if duel.graveyard_is_open():
					duel._close_graveyard()
				if _taken_up(inst, Mtg.Zone.GRAVEYARD):
					graveyard_plays += 1
			"top":
				duel._click_library_top(SEAT)
				if _taken_up(inst, Mtg.Zone.LIBRARY):
					top_plays += 1
			"hymn":
				duel._open_ability_menu(inst)
				duel._ability_menu.hide()
				duel._on_ability_chosen(inst.cur_mana_abilities.size() + int(play[2]))
				if _taken_up(inst, Mtg.Zone.BATTLEFIELD):
					hymns_started += 1
		if verbose:
			print("    > %s: %s (%s)" % [String(play[0]), inst.data.card_name, duel._prompt_label.text])
		return true

	## Did the screen take the gesture up: [param inst] has left [param from]
	## (a land played, a cycled card discarded, a free spell on the stack)
	## or is the cast or activation now pending (waiting for its targets or
	## its mana)? A refused gesture leaves it where it was and nothing pending.
	func _taken_up(inst: CardInstance, from: int) -> bool:
		return inst != null and (inst.zone != from or duel._pending_card == inst)
