extends SceneTree
## Deterministic complete Wizard-v-Wizard Mirage block (Pack 8) duels in
## both rulesets — and the evidence that the block's mechanics were PLAYED,
## not merely loaded: casts per card, activations per ability, triggers per
## card, phasing events, flanking triggers, flash-rider casts and their
## CR 514.3a cleanup-window sacrifices, flash permanents cast at instant
## speed, alternative- and additional-cost casts, cumulative upkeep paid and
## unpaid, damage replacements applied, and the block's mana sources used.
##
## Nine themed 60-card decks (phasing, flanking knights, flash riders,
## costs and cumulative upkeep, damage shields, Karoo lands and mana, charms
## and removal, and two mixed block decks); each round every deck plays the
## next one in rotation, so a round is 9 duels per ruleset, 18 in all.
##
## STRICT. A duel that reaches the turn cap (default 120 — past the 60-card
## decking horizon, so a real game has ended by then), stays inside one turn
## for MAX_ACTIONS_PER_TURN actions, or stops with neither seat able to act
## is a STALL. Any engine/script error or warning logged while a duel runs
## (counted by a [Logger], so nothing has to be grepped) is an ERROR. Every
## duel is still played and reported; the exit status is 2 when any duel
## stalled or errored, 3 for bad arguments, 0 otherwise.
##
## Isolation: requires the repository's `shandalar_test` runtime feature
## (tools/runtime.sh `shandalar_test_profile`), enables Pack 8 IN MEMORY
## ONLY (never written to settings) and writes no Elo, no deck, no log file
## of its own. It needs the pack's rules, not its pictures: the real local
## ZIP or the test fixture both serve.
##
##   . tools/runtime.sh; shandalar_find_godot; shandalar_find_timeout
##   shandalar_test_profile
##   export SHANDALAR_PACK_8="$PWD/../shandalar-packs/Pack-8-Mirage-Block.zip"
##   "$SHANDALAR_TIMEOUT" -k 5 1800 "$GODOT" --headless --path . \
##       --script res://tools/pack_8_duel_audit.gd -- --rounds 10 --seed 87000 \
##       > audit.log 2>&1 </dev/null

const DEFAULT_SEED := 87000
const DEFAULT_TURN_CAP := 120
## A turn that has not ended after this many seat actions is a loop
## (a {0} ability toggled for ever, a priority ping-pong), not a turn.
const MAX_ACTIONS_PER_TURN := 2000
## The pool with Pack 8 alone: 897 core + 621 new + 31 shared reprints.
const POOL_WITH_PACK_8 := 1549
## The lines of a failed duel's log replayed on stderr.
const FAILURE_LOG_TAIL := 60

## Each deck: its name, its basic and nonbasic lands, its spells. 60 cards.
const DECKS := [
	{"name": "Phasing", "lands": {"Island": 24}, "cards": {
		"Merfolk Raiders": 4, "Teferi's Drake": 4, "Shimmering Efreet": 4,
		"Tolarian Drake": 3, "Breezekeeper": 2, "Sandbar Crocodile": 2,
		"Rainbow Efreet": 2, "Vodalian Illusionist": 2, "Teferi's Curse": 3,
		"Cloak of Invisibility": 3, "Shimmer": 1, "Time and Tide": 3,
		"Reality Ripple": 3}},
	{"name": "Knights", "lands": {"Plains": 13, "Mountain": 10}, "cards": {
		"Mtenda Herder": 4, "Femeref Knight": 4, "Zhalfirin Knight": 3,
		"Knight of Valor": 3, "Zhalfirin Commander": 2, "Suq'Ata Lancer": 4,
		"Searing Spear Askari": 3, "Burning Shield Askari": 2, "Agility": 4,
		"Jabari's Banner": 3, "Sidar Jabari": 1, "Telim'Tor": 1,
		"Hearth Charm": 3}},
	{"name": "Flash", "lands": {"Forest": 9, "Plains": 7, "Island": 6,
		"Winding Canyons": 1}, "cards": {
		"King Cheetah": 4, "Benalish Knight": 4, "Armor of Thorns": 4,
		"Spider Climb": 3, "Soar": 3, "Ward of Lights": 2, "Mystic Veil": 2,
		"Grizzly Bears": 3, "River Boa": 3, "Femeref Scouts": 2,
		"Wild Elephant": 3, "Stalking Tiger": 2, "Llanowar Elves": 2}},
	{"name": "Costs", "lands": {"Mountain": 12, "Swamp": 11}, "cards": {
		"Fireblast": 4, "Kaervek's Spite": 2, "Infernal Harvest": 3,
		"Firestorm": 2, "Haunting Misery": 2, "Spinning Darkness": 2,
		"Wicked Reward": 2, "Carrion": 1, "Heat Wave": 1,
		"Heart of Bogardan": 1, "Gallowbraid": 1, "Morinfen": 1,
		"Talruum Minotaur": 3, "Python": 3, "Feral Shadow": 3,
		"Fledgling Djinn": 2, "Incinerate": 2, "Viashino Warrior": 2}},
	{"name": "Shields", "lands": {"Plains": 12, "Mountain": 11}, "cards": {
		"Shadowbane": 3, "Reflect Damage": 3, "Honorable Passage": 3,
		"Blind Fury": 2, "Benevolent Unicorn": 3, "Femeref Healer": 2,
		"Remedy": 2, "Righteous Aura": 1, "Desperate Gambit": 2,
		"Kithkin Armor": 2, "Zhalfirin Crusader": 3, "Ekundu Griffin": 3,
		"Viashino Warrior": 3, "Spitting Drake": 2, "Volcanic Geyser": 2,
		"Ethereal Champion": 1}},
	{"name": "Karoo", "lands": {"Forest": 8, "Mountain": 5, "Jungle Basin": 3,
		"Dormant Volcano": 2, "Lotus Vale": 2, "Crystal Vein": 2,
		"Mountain Valley": 2, "Undiscovered Paradise": 1}, "cards": {
		"Moss Diamond": 2, "Fire Diamond": 3, "Wall of Roots": 4,
		"Quirion Elves": 2, "Uktabi Efreet": 3, "Arctic Wolves": 2,
		"Aboroth": 1, "Mwonvuli Ooze": 2, "Stampeding Wildebeests": 3,
		"Savage Twister": 2, "Torrent of Lava": 2, "Canopy Dragon": 1,
		"Panther Warriors": 3, "Elephant Grass": 1, "Jungle Troll": 2,
		"Uktabi Orangutan": 2}},
	{"name": "Charms", "lands": {"Plains": 12, "Swamp": 11}, "cards": {
		"Ivory Charm": 3, "Hope Charm": 2, "Ebony Charm": 3,
		"Funeral Charm": 3, "Afterlife": 3, "Dark Banishing": 3,
		"Fatal Blow": 2, "Nekrataal": 2, "Abyssal Hunter": 2,
		"Melesse Spirit": 2, "Daraja Griffin": 2, "Wall of Corpses": 2,
		"Cadaverous Knight": 2, "Circle of Despair": 1, "Shadow Rider": 2,
		"Auspicious Ancestor": 2, "Disenchant": 1}},
	{"name": "Jamuraa", "lands": {"Forest": 12, "Island": 11}, "cards": {
		"Warping Wurm": 2, "Pygmy Hippo": 2, "Man-o'-War": 3, "River Boa": 3,
		"Striped Bears": 3, "Giant Mantis": 2, "Femeref Archers": 2,
		"Ophidian": 2, "Sapphire Charm": 3, "Seedling Charm": 2,
		"Emerald Charm": 2, "Memory Lapse": 2, "Dissipate": 2,
		"Stampeding Wildebeests": 3, "Fog Elemental": 2,
		"Katabatic Winds": 1, "Vision Charm": 1}},
	{"name": "Weatherlight", "lands": {"Swamp": 12, "Mountain": 11}, "cards": {
		"Thunderbolt": 3, "Cone of Flame": 2, "Lava Hounds": 2,
		"Bloodrock Cyclops": 3, "Sawtooth Ogre": 2, "Dwarven Berserker": 2,
		"Bogardan Firefiend": 3, "Razortooth Rats": 3,
		"Mischievous Poltergeist": 2, "Zombie Scavengers": 2, "Necratog": 2,
		"Hidden Horror": 2, "Abyssal Gatekeeper": 1, "Tendrils of Despair": 2,
		"Fatal Blow": 2, "Fire Whip": 2, "Goblin Grenadiers": 2}},
]

## Counters a card puts on itself AS THE COST of a mana ability (CR 605,
## no stack, no log line, no event): read off the permanent instead.
const COST_COUNTERS := {"Wall of Roots": "-0/-1"}

## The summary keys, so a zero is printed rather than left out.
const MECHANICS := [
	"phasing events (out + in)", "phased out by the untap step",
	"phased out by an effect", "phased out riding a host",
	"phased in", "flanking triggers", "flanking triggers resolved",
	"flash-rider casts as though it had flash", "flash-rider casts at sorcery speed",
	"flash-rider cleanup sacrifices", "cleanup-step triggers",
	"flash permanents cast at instant speed",
	"alternative-cost casts", "additional object-cost casts",
	"cumulative upkeep triggers", "cumulative upkeep unpaid",
	"damage replacements applied", "nonbasic land mana taps",
	"mana artifact taps", "mana-ability cost counters",
]


## Engine and script errors and warnings, counted as they are logged — the
## duel loop reads and resets the tally around each duel.
class DuelErrors extends Logger:
	var _lock := Mutex.new()
	var errors := 0
	var warnings := 0
	var first := ""

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1
		if first == "":
			first = "%s (%s:%d in %s)" % [rationale if rationale != "" else code,
				file, line, function]
		_lock.unlock()

	func take() -> Dictionary:
		_lock.lock()
		var out := {"errors": errors, "warnings": warnings, "first": first}
		errors = 0
		warnings = 0
		first = ""
		_lock.unlock()
		return out


var _turn_cap := DEFAULT_TURN_CAP
## --verbose: every duel's whole game log on stdout, after its result line.
var _verbose := false
var _errors := DuelErrors.new()
## Card names of every deck, longest first: the damage-replacement lines
## open with the name of the card whose shield applied.
var _deck_names: Array[String] = []


func _initialize() -> void: _run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--version") or args.has("-V"):
		print("pack_8_duel_audit.gd ", ProjectSettings.get_setting("application/config/version", "unknown"))
		quit(0)
		return
	if args.has("--help") or args.has("-h"):
		print("Pack 8 Mirage block audit — complete Wizard duels and actual card and mechanic use in both rulesets.")
		print("--rounds N (default 1, max 1000); --seed N (default %d; fifth-edition duels add 100000)." % DEFAULT_SEED)
		print("Nine themed decks, 18 duels per round (9 modern, 9 fifth).")
		print("--only-index N replays that matchup (zero based, round-major) in both rulesets for debugging.")
		print("--rules modern|fifth|both (default both); --turn-cap N (default %d): reaching it is a STALL." % DEFAULT_TURN_CAP)
		print("--verbose prints every duel's whole game log after its result line.")
		print("Exit 0 = every duel completed cleanly; 2 = a stall, an engine/script error or warning, or a setup failure; 3 = bad arguments.")
		print("Use tools/runtime.sh: shandalar_find_godot; shandalar_find_timeout; shandalar_test_profile.")
		print("Set SHANDALAR_PACK_8 to your locally built Pack-8-Mirage-Block.zip; run with --script res://tools/pack_8_duel_audit.gd.")
		quit(0)
		return
	var rounds := 1
	var base_seed := DEFAULT_SEED
	var only_index := -1
	var editions: Array[String] = ["modern", "fifth"]
	var at := 0
	while at < args.size():
		if args[at] == "--verbose":
			_verbose = true
			at += 1
			continue
		var flag := String(args[at])
		var value := String(args[at + 1]) if at + 1 < args.size() else ""
		if flag == "--rules" and value in ["modern", "fifth", "both"]:
			editions.clear()
			if value != "fifth": editions.append("modern")
			if value != "modern": editions.append("fifth")
			at += 2
			continue
		if flag not in ["--rounds", "--seed", "--only-index", "--turn-cap"] or not value.is_valid_int():
			printerr("Invalid audit arguments; use --help")
			quit(3)
			return
		match flag:
			"--rounds": rounds = int(value)
			"--seed": base_seed = int(value)
			"--only-index": only_index = int(value)
			"--turn-cap": _turn_cap = int(value)
		at += 2
	if rounds < 1 or rounds > 1000 or base_seed < 0 or _turn_cap < 10:
		printerr("Rounds must be 1..1000, the seed nonnegative and the turn cap at least 10")
		quit(3)
		return
	if not OS.has_feature("shandalar_test"):
		printerr("PACK 8 AI AUDIT: requires GODOT_EDITOR_CUSTOM_FEATURES=shandalar_test (tools/runtime.sh shandalar_test_profile)")
		quit(2)
		return
	var packs: Node = root.get_node("CardPacks")
	if not packs.has_pack(MirageBlockPack.ID):
		printerr("PACK 8 AI AUDIT: no valid Pack-8-Mirage-Block.zip found; set SHANDALAR_PACK_8")
		quit(2)
		return
	# In memory only: the third argument keeps the player's (here: the
	# isolated test profile's) settings file untouched.
	Settings.set_value("enabled_card_packs", [MirageBlockPack.ID], false)
	packs._configure_registry()
	CardRegistry.ensure_loaded()
	if CardRegistry.size() != POOL_WITH_PACK_8:
		printerr("PACK 8 AI AUDIT: expected %d cards with Pack 8 alone, found %d" % [POOL_WITH_PACK_8, CardRegistry.size()])
		quit(2)
		return
	var decks := _build_decks()
	if decks.is_empty():
		quit(2)
		return
	OS.add_logger(_errors)
	var duels: Array = []
	var totals := {}   # edition -> {key: count}
	for edition in editions: totals[edition] = {}
	for edition in editions:
		for match_index in DECKS.size() * rounds:
			if only_index >= 0 and match_index != only_index: continue
			var i := match_index % DECKS.size()
			var round_index := match_index / DECKS.size()
			var opponent := (i + 1 + round_index % (DECKS.size() - 1)) % DECKS.size()
			var duel_seed := base_seed + match_index + (100000 if edition == "fifth" else 0)
			var result := _play_duel(edition, duel_seed, decks, i, opponent)
			duels.append(result)
			_merge(totals[edition], result.tally)
	OS.remove_logger(_errors)
	_report(duels, totals, editions)
	var failed := duels.filter(func(d: Dictionary) -> bool: return d.status != "OK")
	if duels.is_empty():
		printerr("PACK 8 AI AUDIT: --only-index selected no duel")
		quit(3)
		return
	if failed.is_empty():
		print("PACK 8 AI AUDIT OK: %d completed full duels, no stall, no engine error" % duels.size())
		quit(0)
	else:
		printerr("PACK 8 AI AUDIT FAILED: %d of %d duels — %d stalled, %d logged errors or warnings" % [
			failed.size(), duels.size(),
			duels.filter(func(d: Dictionary) -> bool: return d.stall != "").size(),
			duels.filter(func(d: Dictionary) -> bool: return int(d.errors) + int(d.warnings) > 0).size()])
		quit(2)


## Every deck as a 60-name list, or [] after naming every problem.
func _build_decks() -> Array:
	var out: Array = []
	var problems: Array[String] = []
	var names := {}
	for spec in DECKS:
		var deck: Array[String] = []
		for part in ["lands", "cards"]:
			for name in spec[part]:
				var n := String(name)
				var copies := int(spec[part][name])
				if not CardRegistry.has_card(n):
					problems.append("%s: no card named %s" % [spec.name, n])
					continue
				var data := CardRegistry.get_card(n)
				if copies > 4 and (data.supertypes & Mtg.Supertype.BASIC) == 0:
					problems.append("%s: %d copies of %s" % [spec.name, copies, n])
				if (data.supertypes & Mtg.Supertype.BASIC) == 0: names[n] = true
				for _c in copies: deck.append(n)
		if deck.size() != 60 and problems.is_empty():
			problems.append("%s: %d cards, not 60" % [spec.name, deck.size()])
		out.append(deck)
	for why in problems: printerr("PACK 8 AI AUDIT: " + why)
	if not problems.is_empty(): return []
	for n in names: _deck_names.append(String(n))
	_deck_names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	return out


## One complete duel: [code]{edition, seed, decks, winner, turns, ms, status,
## stall, errors, warnings, first_error, tally}[/code].
func _play_duel(edition: String, duel_seed: int, decks: Array, i: int, opponent: int) -> Dictionary:
	var game := MtgGame.new()
	var names := ["Mirage " + String(DECKS[i].name), "Mirage " + String(DECKS[opponent].name)]
	game.setup(decks[i], decks[opponent], names[0], names[1], 20, 20, duel_seed)
	game.rules.set_edition(edition)
	var a := AiPlayer.new(0, AiProfile.wizard())
	var b := AiPlayer.new(1, AiProfile.wizard())
	game.set_agent(0, a)
	game.set_agent(1, b)
	var tally := {}
	var watch := {"serial": int(game.get("_flash_cast_serial")), "counters": {}}
	# The bound hook holds the game; disconnecting it breaks the cycle.
	var hook := _on_event.bind(game, tally, watch)
	game.event_occurred.connect(hook)
	_errors.take()   # whatever was logged before this duel is not its own
	var started := Time.get_ticks_msec()
	game.start()
	var stall := _play_out(game, a, b)
	var ms := Time.get_ticks_msec() - started
	game.event_occurred.disconnect(hook)
	var logged := _errors.take()
	_sample_cost_counters(game, watch)
	_read_log(game, tally)
	for id in watch.counters:
		var row: Array = watch.counters[id]
		_bump(tally, "mana-ability cost counters", int(row[1]))
		_bump(tally, "mana ability: %s (%s counter as its cost)" % [row[0], COST_COUNTERS[row[0]]], int(row[1]))
	var status := "OK"
	if stall != "": status = "STALL"
	elif int(logged.errors) + int(logged.warnings) > 0: status = "ERROR"
	var result := {"edition": edition, "seed": duel_seed,
		"decks": [String(DECKS[i].name), String(DECKS[opponent].name)],
		"winner": game.winner, "turns": game.turn_number, "ms": ms,
		"status": status, "stall": stall, "errors": int(logged.errors),
		"warnings": int(logged.warnings), "first_error": String(logged.first),
		"tally": tally}
	_print_duel(result)
	if _verbose:
		for line in game.log_lines: print("  | ", line)
	if status != "OK": _dump(game, result)
	return result


## [method AiPlayer.play_out]'s loop, the same two calls in the same order
## (so a seed plays the same duel), with the audit's stricter stall rules.
## "" when the game ended, otherwise why it is a stall.
func _play_out(game: MtgGame, a: AiPlayer, b: AiPlayer) -> String:
	var turn := game.turn_number
	var in_turn := 0
	while not game.game_over:
		if game.turn_number > _turn_cap:
			return "turn cap %d reached" % _turn_cap
		if game.turn_number != turn:
			turn = game.turn_number
			in_turn = 0
		if in_turn >= MAX_ACTIONS_PER_TURN:
			return "%d actions without leaving turn %d (%s)" % [in_turn, turn,
				Mtg.step_name(game.current_step())]
		if a.act(game) == "" and b.act(game) == "" and not game.game_over:
			return "neither seat could act at %s, turn %d" % [
				Mtg.step_name(game.current_step()), game.turn_number]
		in_turn += 1
	return ""


## The events the log does not spell out: phasing, casts (their payment row,
## their timing, the flash rider), departures in the cleanup step, unpaid
## cumulative upkeep, mana from the block's lands and artifacts.
func _on_event(event: GameEvent, game: MtgGame, tally: Dictionary, watch: Dictionary) -> void:
	var data: Dictionary = event.data
	_sample_cost_counters(game, watch)
	match event.type:
		Mtg.EventType.PHASED_OUT, Mtg.EventType.PHASED_IN:
			var inst: CardInstance = data.get("instance")
			if inst == null: return
			_bump(tally, "phasing events (out + in)")
			var how := "phased in"
			if event.type == Mtg.EventType.PHASED_OUT:
				if bool(data.get("indirect", false)): how = "phased out riding a host"
				elif game.current_step() == Mtg.Step.UNTAP: how = "phased out by the untap step"
				else: how = "phased out by an effect"
			elif bool(data.get("indirect", false)):
				how = "phased in riding a host"
			_bump(tally, how)
			_bump(tally, "phasing: %s %s" % [inst.data.card_name, how])
		Mtg.EventType.SPELL_CAST:
			_on_cast(game, data, tally, watch)
		Mtg.EventType.LEAVES_BATTLEFIELD:
			var gone: CardInstance = data.get("instance")
			if gone == null: return
			var memory: Dictionary = data.get("memory", {})
			if game.current_step() == Mtg.Step.CLEANUP and bool(data.get("sacrificed", false)) \
					and bool(memory.get("flash_cast", false)):
				_bump(tally, "flash-rider cleanup sacrifices")
				_bump(tally, "flash rider: %s sacrificed in the cleanup step" % gone.data.card_name)
			elif gone.data.is_land() and bool(data.get("sacrificed", false)):
				_bump(tally, "land sacrificed: " + gone.data.card_name)
		Mtg.EventType.CUMULATIVE_UPKEEP_UNPAID:
			var cu: CardInstance = data.get("instance")
			_bump(tally, "cumulative upkeep unpaid")
			if cu != null:
				_bump(tally, "cumulative upkeep: %s not paid" % cu.data.card_name)
		Mtg.EventType.TAPPED_FOR_MANA:
			var land: CardInstance = data.get("instance")
			if land != null and (land.data.supertypes & Mtg.Supertype.BASIC) == 0:
				_bump(tally, "nonbasic land mana taps")
				_bump(tally, "mana: %s tapped" % land.data.card_name)
		Mtg.EventType.BECAME_TAPPED:
			var thing: CardInstance = data.get("instance")
			if thing != null and not thing.is_land() and not thing.is_creature() \
					and not thing.data.mana_abilities.is_empty():
				_bump(tally, "mana artifact taps")
				_bump(tally, "mana: %s tapped" % thing.data.card_name)
		Mtg.EventType.ENTERS_BATTLEFIELD:
			var entered: CardInstance = data.get("instance")
			if entered != null and entered.data.is_land() \
					and (entered.data.supertypes & Mtg.Supertype.BASIC) == 0:
				_bump(tally, "land entered: " + entered.data.card_name)
			if entered != null and COST_COUNTERS.has(entered.data.card_name):
				watch.counters[entered.id] = [entered.data.card_name, 0]


## A spell was cast: its payment row (CardData.with_alternative_cost), its
## additional object costs, the flash rider and instant-speed permanents.
func _on_cast(game: MtgGame, data: Dictionary, tally: Dictionary, watch: Dictionary) -> void:
	var inst: CardInstance = data.get("instance")
	if inst == null: return
	var pid := int(data.get("controller", inst.controller_id))
	var card := inst.data
	var item: StackItem = null
	for k in range(game.stack.size() - 1, -1, -1):
		if game.stack[k].card == inst and game.stack[k].kind == Mtg.StackKind.SPELL:
			item = game.stack[k]
			break
	if item != null and item.mode >= 0 and item.mode < card.modes.size():
		var row: Dictionary = card.modes[item.mode]
		if row.has("payment"):
			_bump(tally, "alternative-cost casts")
			_bump(tally, "alternative cost: %s — %s" % [card.card_name, String(row.get("label", "?"))])
	if not card.object_costs.is_empty():
		_bump(tally, "additional object-cost casts")
		_bump(tally, "additional cost: %s%s" % [card.card_name,
			(" (X=%d)" % item.x_value) if item != null and item.x_value > 0 else ""])
	# The engine numbers each flash-rider cast that schedules its cleanup
	# sacrifice (MtgGame._schedule_flash_rider_sacrifice) before SPELL_CAST.
	var serial := int(game.get("_flash_cast_serial"))
	if card.flash_rider:
		if serial != int(watch.serial):
			_bump(tally, "flash-rider casts as though it had flash")
			_bump(tally, "flash rider: %s cast as though it had flash" % card.card_name)
		else:
			_bump(tally, "flash-rider casts at sorcery speed")
	elif card.is_permanent_type() and not card.is_land():
		var step := game.current_step()
		if game.active_player != pid or not (step == Mtg.Step.MAIN1 or step == Mtg.Step.MAIN2) \
				or game.stack.size() > 1:
			_bump(tally, "flash permanents cast at instant speed")
			_bump(tally, "flash: %s cast at instant speed" % card.card_name)
	watch.serial = serial


## Mana abilities whose cost is a counter on their own source leave no
## line and no event; the counters stay, so the most ever seen is the use.
func _sample_cost_counters(game: MtgGame, watch: Dictionary) -> void:
	for id in watch.counters:
		var inst := game.find_instance(int(id))
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD: continue
		var row: Array = watch.counters[id]
		var seen := int(inst.counters.get(COST_COUNTERS[row[0]], 0))
		if seen > int(row[1]): row[1] = seen


## The log's own record: casts, activations (per ability), triggers (per
## card; flanking, cumulative upkeep and cleanup-step ones apart), plays of
## nonbasic lands, and the lines the damage-replacement suite writes.
func _read_log(game: MtgGame, tally: Dictionary) -> void:
	for index in game.log_lines.size():
		var line := game.log_lines[index]
		var meta: Dictionary = game.log_meta[index]
		var kind := String(meta.get("kind", ""))
		var card := String(meta.get("card", ""))
		match kind:
			"cast":
				if card != "": _bump(tally, "cast: " + card)
			"activate":
				var at := line.find(" activates ")
				if at >= 0: _bump(tally, "activate: " + _short(line.substr(at + 11)))
			"play":
				if card != "" and _deck_names.has(card): _bump(tally, "play: " + card)
			"trigger":
				var text := line.trim_prefix("Trigger: ")
				if card != "": _bump(tally, "trigger: " + card)
				if text.contains(Flanking.TEXT):
					_bump(tally, "flanking triggers")
					_bump(tally, "flanking: %s triggered" % card)
				if text.to_lower().contains("cumulative upkeep"):
					_bump(tally, "cumulative upkeep triggers")
					_bump(tally, "cumulative upkeep: %s trigger" % card)
				if int(meta.get("step", -1)) == Mtg.Step.CLEANUP:
					_bump(tally, "cleanup-step triggers")
					_bump(tally, "cleanup trigger: " + _short(text))
			"resolve":
				if line.contains(Flanking.TEXT): _bump(tally, "flanking triggers resolved")
			"":
				if line.contains("damage") and (line.contains(" prevents ") \
						or line.contains(" instead") or line.contains(" becomes ")):
					for name in _deck_names:
						if line.begins_with(name):
							_bump(tally, "damage replacements applied")
							_bump(tally, "damage replaced: " + name)
							break


func _print_duel(d: Dictionary) -> void:
	var tally: Dictionary = d.tally
	var winner := "none"
	if int(d.winner) >= 0: winner = String(d.decks[int(d.winner)])
	print("PACK 8 AI DUEL %s: %s seed %d %s vs %s — winner %s, %d turns, %.1f s; phasing %d, flanking %d, rider casts %d, cleanup sacrifices %d, alt-cost %d, extra-cost %d, cumulative upkeep %d, damage replaced %d; errors %d, warnings %d%s" % [
		d.status, d.edition, d.seed, d.decks[0], d.decks[1], winner, d.turns,
		float(d.ms) / 1000.0, int(tally.get("phasing events (out + in)", 0)),
		int(tally.get("flanking triggers", 0)),
		int(tally.get("flash-rider casts as though it had flash", 0)),
		int(tally.get("flash-rider cleanup sacrifices", 0)),
		int(tally.get("alternative-cost casts", 0)),
		int(tally.get("additional object-cost casts", 0)),
		int(tally.get("cumulative upkeep triggers", 0)),
		int(tally.get("damage replacements applied", 0)),
		d.errors, d.warnings,
		(" — " + String(d.stall)) if String(d.stall) != "" else ""])


func _dump(game: MtgGame, d: Dictionary) -> void:
	printerr("PACK 8 AI AUDIT %s: %s seed %d %s vs %s, turn %d%s%s" % [d.status, d.edition,
		d.seed, d.decks[0], d.decks[1], game.turn_number,
		(" — " + String(d.stall)) if String(d.stall) != "" else "",
		(" — first error: " + String(d.first_error)) if String(d.first_error) != "" else ""])
	for player in game.players:
		var hand: Array[String] = []
		for card in player.hand: hand.append(card.data.card_name)
		var board: Array[String] = []
		for card in player.battlefield:
			board.append("%s %s/%s tapped=%s" % [card.data.card_name, card.cur_power, card.cur_toughness, card.tapped])
		printerr("STATE ", player.player_name, " life=", player.life, " library=", player.library.size(), " hand=", hand)
		printerr("BOARD ", board)
	for line in game.log_lines.slice(-FAILURE_LOG_TAIL): printerr(line)


func _report(duels: Array, totals: Dictionary, editions: Array[String]) -> void:
	var all := {}
	for edition in editions: _merge(all, totals[edition])
	for key in MECHANICS:
		print("PACK 8 MECHANIC: %s = %d (%s)" % [key, int(all.get(key, 0)), _split(totals, editions, key)])
	var keys: Array = all.keys().filter(func(k: String) -> bool: return not MECHANICS.has(k))
	keys.sort()
	for key in keys:
		print("PACK 8 ACTUAL USE: %s = %d (%s)" % [key, int(all[key]), _split(totals, editions, key)])
	# The Mirage block cards in these decks that no duel ever cast or played:
	# reported, not failed — a short campaign need not draw everything.
	var block := MirageBlockPack.names()
	var unused: Array[String] = []
	for name in _deck_names:
		if not block.has(name): continue
		var land := CardRegistry.get_card(name).is_land()
		if int(all.get(("play: " if land else "cast: ") + name, 0)) == 0: unused.append(name)
	unused.sort()
	var in_decks := 0
	for name in _deck_names:
		if block.has(name): in_decks += 1
	print("PACK 8 NOT CAST OR PLAYED (%d of %d block names in the decks): %s" % [unused.size(),
		in_decks, ", ".join(PackedStringArray(unused)) if not unused.is_empty() else "none"])
	var turns: Array = duels.map(func(d: Dictionary) -> int: return int(d.turns))
	if not turns.is_empty():
		print("PACK 8 DUEL LENGTHS: %d-%d turns over %d duels" % [turns.min(), turns.max(), duels.size()])


## "modern 3, fifth 4" — one key's count per ruleset.
static func _split(totals: Dictionary, editions: Array[String], key: String) -> String:
	var parts := PackedStringArray()
	for edition in editions:
		parts.append("%s %d" % [edition, int(totals[edition].get(key, 0))])
	return ", ".join(parts)


static func _bump(tally: Dictionary, key: String, by := 1) -> void:
	tally[key] = int(tally.get(key, 0)) + by


static func _merge(into: Dictionary, from: Dictionary) -> void:
	for key in from: into[key] = int(into.get(key, 0)) + int(from[key])


static func _short(text: String) -> String:
	return text if text.length() <= 90 else text.substr(0, 87) + "..."
