extends SceneTree
## Deterministic complete Tempest block (Pack 9) duels in both rulesets —
## Wizard v Wizard and Wizard v Apprentice — and the evidence that the
## block's mechanics were PLAYED, not merely loaded: casts per card,
## activations per ability, triggers per card, shadow attacks and blocks,
## buyback paid and returned, the rows Dream Halls and Aluren grant, licids
## becoming Auras and their effects ended, Volrath's Curse ignored, Sliver
## grants used, Spike counters moved, Oath triggers, the block's sweepers
## and one-offs (Humility, Living Death, Cataclysm, Ertai's Meddling,
## Volrath's Shapeshifter, Static Orb), en-Kor redirects and retargets,
## damage replacements and the block's mana sources — plus every refusal
## the engine handed the AI.
##
## Nine themed 60-card decks (shadow, Slivers, licids, Spikes, buyback,
## Exodus Oaths, Humility control, Stronghold aggro, Tempest artifacts and
## lands); each round every deck plays the next one in rotation, once
## Wizard v Wizard and once Wizard v Apprentice (the Apprentice alternates
## seats), so a round is 18 duels per ruleset, 36 in all.
##
## STRICT. A duel that reaches the turn cap (default 120 — past the 60-card
## decking horizon, so a real game has ended by then), stays inside one turn
## for MAX_ACTIONS_PER_TURN actions, or stops with neither seat able to act
## is a STALL. Any engine/script error or warning logged while a duel runs
## (counted by a [Logger], so nothing has to be grepped) is an ERROR. Every
## duel is still played and reported; the exit status is 2 when any duel
## stalled or errored, 3 for bad arguments, 0 otherwise. The AI's refused
## casts and activations are reported (per card and reason), never failed:
## one is the engine refusing an illegal try, and the AI drops that card
## for the rest of the step.
##
## Isolation: requires the repository's `shandalar_test` runtime feature
## (tools/runtime.sh `shandalar_test_profile`), enables Pack 9 IN MEMORY
## ONLY (never written to settings) and writes no Elo, no deck, no log file
## of its own. It needs the pack's rules, not its pictures: the real local
## ZIP or the test fixture both serve.
##
##   . tools/runtime.sh; shandalar_find_godot; shandalar_find_timeout
##   shandalar_test_profile
##   export SHANDALAR_PACK_9="$PWD/../shandalar-packs/Pack-9-Tempest-Block.zip"
##   "$SHANDALAR_TIMEOUT" -k 5 3600 "$GODOT" --headless --path . \
##       --script res://tools/pack_9_duel_audit.gd -- --rounds 6 --seed 97000 \
##       > audit.log 2>&1 </dev/null

const DEFAULT_SEED := 97000
const DEFAULT_TURN_CAP := 120
## A turn that has not ended after this many seat actions is a loop
## (a {0} ability toggled for ever, a priority ping-pong), not a turn.
const MAX_ACTIONS_PER_TURN := 2000
## The pool with Pack 9 alone: 897 core + 574 new + 27 shared reprints.
const POOL_WITH_PACK_9 := 1498
## The lines of a failed duel's log replayed on stderr.
const FAILURE_LOG_TAIL := 60
## Wizard-v-Apprentice duels draw their seeds this far above the
## Wizard-v-Wizard ones, so the two pairings never share a seed.
const APPRENTICE_SEED_OFFSET := 50000
## One card refused this often for one reason in one duel is reported as
## a refusal loop (the engine said no again and again, step after step).
const REFUSAL_LOOP := 20

## Each deck: its name, its basic and nonbasic lands, its spells. 60 cards.
## Pack 9 and the 1997 core only.
const DECKS := [
	{"name": "Shadow", "lands": {"Plains": 12, "Swamp": 11}, "cards": {
		"Soltari Foot Soldier": 4, "Dauthi Slayer": 4, "Soltari Lancer": 3,
		"Dauthi Horror": 3, "Dauthi Marauder": 3, "Soltari Monk": 2,
		"Soltari Priest": 2, "Dauthi Mercenary": 2, "Soltari Champion": 2,
		"Soltari Trooper": 2, "Dauthi Ghoul": 2, "Dauthi Jackal": 2,
		"Dauthi Embrace": 2, "Circle of Protection: Shadow": 1,
		"Dauthi Warlord": 1, "Soltari Visionary": 1, "Dauthi Cutthroat": 1}},
	{"name": "Slivers", "lands": {"Plains": 4, "Island": 4, "Swamp": 4,
		"Mountain": 5, "Forest": 5, "City of Brass": 2}, "cards": {
		"Muscle Sliver": 4, "Metallic Sliver": 4, "Winged Sliver": 3,
		"Heart Sliver": 3, "Clot Sliver": 3, "Horned Sliver": 2,
		"Talon Sliver": 2, "Armor Sliver": 2, "Barbed Sliver": 2,
		"Spined Sliver": 3, "Acidic Sliver": 2, "Victual Sliver": 1,
		"Crystalline Sliver": 1, "Hibernation Sliver": 1, "Mnemonic Sliver": 1,
		"Mindwhip Sliver": 1, "Sliver Queen": 1}},
	{"name": "Licids", "lands": {"Plains": 8, "Mountain": 8, "Forest": 8}, "cards": {
		"Enraging Licid": 4, "Quickening Licid": 4, "Nurturing Licid": 3,
		"Calming Licid": 3, "Convulsing Licid": 3, "Tempting Licid": 3,
		"Transmogrifying Licid": 2, "Jackal Pup": 4, "Rootwalla": 3,
		"Youthful Knight": 3, "Skyshroud Troopers": 2, "Canopy Spider": 2}},
	{"name": "Spikes", "lands": {"Forest": 23}, "cards": {
		"Spike Feeder": 4, "Spike Worker": 3, "Spike Colony": 3,
		"Spike Drone": 3, "Spike Weaver": 2, "Spike Soldier": 2,
		"Spike Hatcher": 2, "Spike Breeder": 2, "Spike Rogue": 2,
		"Aluren": 2, "Wall of Blossoms": 3, "Plated Rootwalla": 2,
		"Elvish Fury": 2, "Skyshroud Troopers": 2, "Heartwood Dryad": 2,
		"Survival of the Fittest": 1}},
	{"name": "Buyback", "lands": {"Island": 12, "Mountain": 12}, "cards": {
		"Searing Touch": 4, "Capsize": 3, "Whispers of the Muse": 3,
		"Forbid": 3, "Fanning the Flames": 2, "Seething Anger": 2,
		"Shattering Pulse": 1, "Mind Games": 2, "Whim of Volrath": 1,
		"Memory Crystal": 2, "Flowstone Flood": 1, "Dream Halls": 2,
		"Mogg Fanatic": 3, "Fighting Drake": 3, "Rootwater Hunter": 2,
		"Canyon Drake": 2}},
	{"name": "Oaths", "lands": {"Forest": 12, "Plains": 11}, "cards": {
		"Oath of Druids": 2, "Oath of Lieges": 2, "Keeper of the Beasts": 2,
		"Keeper of the Light": 2, "Paladin en-Vec": 2, "Shield Mate": 2,
		"Skyshroud Elite": 2, "Skyshroud War Beast": 2, "Plated Rootwalla": 2,
		"Elvish Berserker": 2, "Crashing Boars": 2, "Elven Palisade": 1,
		"Reap": 1, "Mirri, Cat Warrior": 2, "Convalescence": 1,
		"Zealots en-Dal": 2, "Soul Warden": 3, "Welkin Hawk": 2,
		"Standing Troops": 2, "Pegasus Stampede": 1}},
	{"name": "Humility", "lands": {"Plains": 12, "Island": 12}, "cards": {
		"Humility": 3, "Cataclysm": 1, "Ertai's Meddling": 2, "Dismiss": 2,
		"Mana Leak": 3, "Static Orb": 2, "Propaganda": 2, "Winds of Rath": 1,
		"Silver Wyvern": 2, "Spirit en-Kor": 2, "Nomads en-Kor": 2,
		"Warrior en-Kor": 2, "Volrath's Curse": 2, "Rootwater Matriarch": 1,
		"Wall of Tears": 2, "Serra Angel": 2, "Volrath's Shapeshifter": 2,
		"Kor Chant": 1, "Ephemeron": 1, "Interdict": 1}},
	{"name": "Stronghold", "lands": {"Mountain": 12, "Swamp": 11}, "cards": {
		"Mogg Flunkies": 3, "Flowstone Hellion": 2, "Flowstone Mauler": 1,
		"Furnace Spirit": 2, "Shard Phoenix": 1, "Spitting Hydra": 1,
		"Dungeon Shade": 2, "Morgue Thrull": 1, "Revenant": 1,
		"Stronghold Assassin": 2, "Mindwarper": 1, "Skeleton Scavengers": 1,
		"Foul Imp": 1, "Mogg Maniac": 2, "Mogg Bombers": 1,
		"Crovax the Cursed": 1, "Grave Pact": 1, "Living Death": 1,
		"Shock": 2, "Fanning the Flames": 2, "Seething Anger": 1,
		"Death Stroke": 2, "Rabid Rats": 1, "Dauthi Trapper": 2,
		"Dauthi Jackal": 2}},
	{"name": "Artifacts", "lands": {"Mountain": 16, "Wasteland": 2,
		"Ancient Tomb": 2, "Stalking Stones": 2, "City of Traitors": 1}, "cards": {
		"Cursed Scroll": 2, "Mogg Cannon": 1, "Jinxed Idol": 1,
		"Patchwork Gnomes": 2, "Bottle Gnomes": 3, "Flowstone Sculpture": 1,
		"Telethopter": 2, "Scalding Tongs": 1, "Grindstone": 1,
		"Torture Chamber": 1, "Magnetic Web": 1, "Echo Chamber": 1,
		"Lotus Petal": 2, "Puppet Strings": 1, "Squee's Toy": 1,
		"Thumbscrews": 1, "Energizer": 1, "Manakin": 2, "Phyrexian Hulk": 2,
		"Coiled Tinviper": 2, "Mogg Fanatic": 2, "Kindle": 2, "Shock": 2,
		"Fireslinger": 2}},
]

## The summary keys, so a zero is printed rather than left out.
const MECHANICS := [
	"shadow attackers declared", "shadow attackers unblocked",
	"shadow attackers blocked", "blocks by creatures with shadow",
	"buyback casts (buyback paid)", "buyback returns to hand",
	"granted-row casts (Dream Halls, Aluren)",
	"licid activations (became an Aura)", "licid effects ended (special action)",
	"licids a creature again", "Volrath's Curse ignored (special action)",
	"Sliver attackers with a granted keyword", "granted Sliver abilities activated",
	"Spike abilities activated", "Spike +1/+1 counters removed",
	"Oath triggers", "Oath of Druids reveals",
	"Humility casts", "Living Death casts", "Cataclysm casts",
	"Ertai's Meddling casts", "delayed spells returned to the stack",
	"Volrath's Shapeshifter end steps as a copy", "untap steps under Static Orb",
	"en-Kor redirect activations", "damage redirected", "spells or abilities retargeted",
	"Magnetic Web activations", "damage replacements applied",
	"nonbasic land mana taps", "mana artifact taps",
	"AI refusals (casts and activations)",
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
		print("pack_9_duel_audit.gd ", ProjectSettings.get_setting("application/config/version", "unknown"))
		quit(0)
		return
	if args.has("--help") or args.has("-h"):
		print("Pack 9 Tempest block audit — complete Wizard duels and actual card and mechanic use in both rulesets.")
		print("--rounds N (default 1, max 1000); --seed N (default %d; fifth-edition duels add 100000," % DEFAULT_SEED)
		print("  Wizard-v-Apprentice duels add %d)." % APPRENTICE_SEED_OFFSET)
		print("Nine themed decks; per round 9 matchups x the pilots x the rulesets (36 with the defaults).")
		print("--pilots wizard|apprentice|both (default both): Wizard v Wizard, Wizard v Apprentice")
		print("  (the Apprentice sits in seat 1 on an even matchup, seat 0 on an odd one), or both.")
		print("--only-index N replays that matchup (zero based, round-major: a duel line's seed minus --seed,")
		print("  less the fifth and Apprentice offsets) in each ruleset and pilot pairing; it implies its rounds.")
		print("--rules modern|fifth|both (default both); --turn-cap N (default %d): reaching it is a STALL." % DEFAULT_TURN_CAP)
		print("--verbose prints every duel's whole game log after its result line.")
		print("Exit 0 = every duel completed cleanly; 2 = a stall, an engine/script error or warning, or a setup failure; 3 = bad arguments.")
		print("Use tools/runtime.sh: shandalar_find_godot; shandalar_find_timeout; shandalar_test_profile.")
		print("Set SHANDALAR_PACK_9 to your locally built Pack-9-Tempest-Block.zip; run with --script res://tools/pack_9_duel_audit.gd.")
		quit(0)
		return
	var rounds := 1
	var base_seed := DEFAULT_SEED
	var only_index := -1
	var editions: Array[String] = ["modern", "fifth"]
	var pilots: Array[String] = ["wizard", "apprentice"]
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
		if flag == "--pilots" and value in ["wizard", "apprentice", "both"]:
			pilots.clear()
			if value != "apprentice": pilots.append("wizard")
			if value != "wizard": pilots.append("apprentice")
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
	# A replayed matchup brings its own round: --only-index 55 is round 7's
	# second matchup, whatever --rounds says.
	if only_index >= 0:
		rounds = maxi(rounds, only_index / DECKS.size() + 1)
	if not OS.has_feature("shandalar_test"):
		printerr("PACK 9 AI AUDIT: requires GODOT_EDITOR_CUSTOM_FEATURES=shandalar_test (tools/runtime.sh shandalar_test_profile)")
		quit(2)
		return
	var packs: Node = root.get_node("CardPacks")
	if not packs.has_pack(TempestBlockPack.ID):
		printerr("PACK 9 AI AUDIT: no valid Pack-9-Tempest-Block.zip found; set SHANDALAR_PACK_9")
		quit(2)
		return
	# In memory only: the third argument keeps the player's (here: the
	# isolated test profile's) settings file untouched.
	Settings.set_value("enabled_card_packs", [TempestBlockPack.ID], false)
	packs._configure_registry()
	CardRegistry.ensure_loaded()
	if CardRegistry.size() != POOL_WITH_PACK_9:
		printerr("PACK 9 AI AUDIT: expected %d cards with Pack 9 alone, found %d" % [POOL_WITH_PACK_9, CardRegistry.size()])
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
			for pilot in pilots:
				var duel_seed := base_seed + match_index + (100000 if edition == "fifth" else 0) \
					+ (APPRENTICE_SEED_OFFSET if pilot == "apprentice" else 0)
				# The Apprentice alternates seats, so neither deck always has it.
				var apprentice_seat := -1
				if pilot == "apprentice": apprentice_seat = 1 if match_index % 2 == 0 else 0
				var result := _play_duel(edition, duel_seed, decks, i, opponent, apprentice_seat)
				duels.append(result)
				_merge(totals[edition], result.tally)
	OS.remove_logger(_errors)
	if duels.is_empty():
		printerr("PACK 9 AI AUDIT: --only-index selected no duel")
		quit(3)
		return
	_report(duels, totals, editions)
	var failed := duels.filter(func(d: Dictionary) -> bool: return d.status != "OK")
	if failed.is_empty():
		print("PACK 9 AI AUDIT OK: %d completed full duels, no stall, no engine error" % duels.size())
		quit(0)
	else:
		printerr("PACK 9 AI AUDIT FAILED: %d of %d duels — %d stalled, %d logged errors or warnings" % [
			failed.size(), duels.size(),
			duels.filter(func(d: Dictionary) -> bool: return d.stall != "").size(),
			duels.filter(func(d: Dictionary) -> bool: return int(d.errors) + int(d.warnings) > 0).size()])
		quit(2)


## Every deck as a 60-name list, or [] after naming every problem.
func _build_decks() -> Array:
	var out: Array = []
	var problems: Array[String] = []
	var names := {}
	# Pack 9 alone is enabled, so the registry holds the core and the block
	# (with the reprints it provides) and nothing else: every name found is
	# one of those.
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
	for why in problems: printerr("PACK 9 AI AUDIT: " + why)
	if not problems.is_empty(): return []
	for n in names: _deck_names.append(String(n))
	_deck_names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	return out


## One complete duel: [code]{edition, seed, decks, pilots, winner, turns, ms,
## status, stall, errors, warnings, first_error, refusals, tally}[/code].
## [param apprentice_seat] is the seat the Apprentice plays, -1 for none.
func _play_duel(edition: String, duel_seed: int, decks: Array, i: int, opponent: int,
		apprentice_seat: int) -> Dictionary:
	var game := MtgGame.new()
	var names := ["Tempest " + String(DECKS[i].name), "Tempest " + String(DECKS[opponent].name)]
	game.setup(decks[i], decks[opponent], names[0], names[1], 20, 20, duel_seed)
	game.rules.set_edition(edition)
	var a := AiPlayer.new(0, AiProfile.apprentice() if apprentice_seat == 0 else AiProfile.wizard())
	var b := AiPlayer.new(1, AiProfile.apprentice() if apprentice_seat == 1 else AiProfile.wizard())
	game.set_agent(0, a)
	game.set_agent(1, b)
	var tally := {}
	# The bound hook holds the game; disconnecting it breaks the cycle.
	var hook := _on_event.bind(game, tally)
	game.event_occurred.connect(hook)
	_errors.take()   # whatever was logged before this duel is not its own
	var started := Time.get_ticks_msec()
	game.start()
	var stall := _play_out(game, a, b)
	var ms := Time.get_ticks_msec() - started
	game.event_occurred.disconnect(hook)
	var logged := _errors.take()
	var refusals := _read_log(game, tally)
	var status := "OK"
	if stall != "": status = "STALL"
	elif int(logged.errors) + int(logged.warnings) > 0: status = "ERROR"
	var pilot_names := ["Wizard", "Wizard"]
	if apprentice_seat >= 0: pilot_names[apprentice_seat] = "Apprentice"
	var result := {"edition": edition, "seed": duel_seed,
		"decks": [String(DECKS[i].name), String(DECKS[opponent].name)],
		"pilots": pilot_names,
		"winner": game.winner, "turns": game.turn_number, "ms": ms,
		"status": status, "stall": stall, "errors": int(logged.errors),
		"warnings": int(logged.warnings), "first_error": String(logged.first),
		"refusals": refusals, "tally": tally}
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


## The events the log does not spell out: shadow in combat, how each spell
## was paid (buyback, a granted row), Sliver grants and Spike counters in
## use, Static Orb's untap steps, Volrath's Shapeshifter as a copy, and
## mana from the block's lands and artifacts.
func _on_event(event: GameEvent, game: MtgGame, tally: Dictionary) -> void:
	var data: Dictionary = event.data
	match event.type:
		Mtg.EventType.DECLARED_ATTACKERS:
			for attacker in data.get("attackers", []):
				var inst := attacker as CardInstance
				if inst == null: continue
				if inst.has_keyword(Mtg.Keyword.SHADOW):
					_bump(tally, "shadow attackers declared")
					_bump(tally, "shadow attack: " + inst.data.card_name)
				if inst.has_subtype("sliver"):
					for k in _granted_keywords(inst):
						_bump(tally, "Sliver attackers with a granted keyword")
						_bump(tally, "sliver grant: %s attacked with %s" % [inst.data.card_name, k])
						break
		Mtg.EventType.BLOCKED:
			var attacker: CardInstance = data.get("attacker")
			var blocker: CardInstance = data.get("blocker")
			if attacker != null and attacker.has_keyword(Mtg.Keyword.SHADOW):
				_bump(tally, "shadow attackers blocked")
				if blocker != null:
					_bump(tally, "shadow attacker blocked by " + blocker.data.card_name)
			if blocker != null and blocker.has_keyword(Mtg.Keyword.SHADOW):
				_bump(tally, "blocks by creatures with shadow")
				_bump(tally, "shadow block: " + blocker.data.card_name)
		Mtg.EventType.UNBLOCKED_ATTACKER:
			var through: CardInstance = data.get("instance")
			if through != null and through.has_keyword(Mtg.Keyword.SHADOW):
				_bump(tally, "shadow attackers unblocked")
		Mtg.EventType.SPELL_CAST:
			_on_cast(game, data, tally)
		Mtg.EventType.ABILITY_ACTIVATED:
			var source: CardInstance = data.get("instance")
			var ability: Variant = data.get("ability")
			if source == null or not (ability is ActivatedAbility): return
			if source.has_subtype("sliver") and not source.data.activated_abilities.has(ability):
				_bump(tally, "granted Sliver abilities activated")
				_bump(tally, "sliver grant: %s — %s" % [source.data.card_name,
					_short((ability as ActivatedAbility).text)])
			if source.has_subtype("spike"):
				_bump(tally, "Spike abilities activated")
			if source.data.card_name.ends_with("en-Kor"):
				_bump(tally, "en-Kor redirect activations")
			if source.data.card_name == "Magnetic Web":
				_bump(tally, "Magnetic Web activations")
		Mtg.EventType.COUNTERS_REMOVED:
			var from: CardInstance = data.get("instance")
			if from != null and from.has_subtype("spike") and String(data.get("kind", "")) == "+1/+1":
				_bump(tally, "Spike +1/+1 counters removed", int(data.get("removed", 1)))
		Mtg.EventType.UPKEEP_START:
			if int(game.untap_caps.get("permanent", -1)) >= 0 \
					and String(game.untap_cap_sources.get("permanent", "")) == "Static Orb":
				_bump(tally, "untap steps under Static Orb")
		Mtg.EventType.END_STEP_START:
			for inst in game.all_battlefield():
				if inst.data.graveyard_top_base != null and game.is_present(inst):
					_bump(tally, "Volrath's Shapeshifter end steps as a copy")
					_bump(tally, "shapeshifter: a copy of " + inst.data.card_name)
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


## A Sliver's live keywords it does not print: what a Sliver lord grants.
static func _granted_keywords(inst: CardInstance) -> Array[String]:
	var out: Array[String] = []
	for k in [Mtg.Keyword.FLYING, Mtg.Keyword.HASTE, Mtg.Keyword.TRAMPLE,
			Mtg.Keyword.FIRST_STRIKE]:
		if inst.has_keyword(k) and not inst.data.has_keyword(k):
			out.append(String(Mtg.Keyword.keys()[k]).to_lower())
	return out


## A spell was cast: how it was paid — with buyback, through a row a
## permanent granted (Dream Halls, Aluren: the stack item names it) — and
## the block's one-offs the summary counts by name.
func _on_cast(game: MtgGame, data: Dictionary, tally: Dictionary) -> void:
	var inst: CardInstance = data.get("instance")
	if inst == null: return
	var card := inst.data
	var item := game.find_stack_item(inst)
	if item != null and bool(item.cost_paid.get("buyback", false)):
		_bump(tally, "buyback casts (buyback paid)")
		_bump(tally, "buyback paid: " + card.card_name)
	if item != null:
		for granter in ["Dream Halls", "Aluren"]:
			if item.description.contains("(%s)" % granter):
				_bump(tally, "granted-row casts (Dream Halls, Aluren)")
				_bump(tally, "granted row: %s cast through %s" % [card.card_name, granter])
	match card.card_name:
		"Humility": _bump(tally, "Humility casts")
		"Living Death": _bump(tally, "Living Death casts")
		"Cataclysm": _bump(tally, "Cataclysm casts")
		"Ertai's Meddling": _bump(tally, "Ertai's Meddling casts")


## The log's own record: casts, activations (per ability), triggers (per
## card; the Oaths apart), plays of nonbasic lands, licids, the Curse,
## buyback returns, delayed spells, redirects and retargets, the lines the
## damage-replacement suite writes, and the AI's refused tries. Returns the
## refusals `{"card: reason": count}` of this duel.
func _read_log(game: MtgGame, tally: Dictionary) -> Dictionary:
	var refusals := {}
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
				if card != "": _bump(tally, "trigger: " + card)
				if card.begins_with("Oath of "):
					_bump(tally, "Oath triggers")
			_:
				_read_plain_line(line, tally, refusals)
	for key in refusals:
		_bump(tally, "AI refusals (casts and activations)", int(refusals[key]))
		_bump(tally, "AI refused: " + String(key), int(refusals[key]))
	return refusals


## One log line without a kind of its own (or with one the audit does not
## read): the block's special actions and the engine's own sentences.
func _read_plain_line(line: String, tally: Dictionary, refusals: Dictionary) -> void:
	if line.begins_with("(AI cast of ") or line.begins_with("(AI activation of "):
		var key := line.trim_prefix("(AI cast of ").trim_prefix("(AI activation of ") \
			.trim_suffix(")").replace(" refused: ", ": ")
		key = _short(key)
		refusals[key] = int(refusals.get(key, 0)) + 1
		return
	if line.contains(" becomes an Aura attached to "):
		_bump(tally, "licid activations (became an Aura)")
		_bump(tally, "licid: " + line.get_slice(" becomes an Aura", 0))
	elif line.contains(" becomes an Aura but can't be attached"):
		_bump(tally, "licid: an Aura with nothing to enchant")
	elif line.contains(" to end ") and line.ends_with("'s effect"):
		_bump(tally, "licid effects ended (special action)")
	elif line.ends_with(" is a creature again"):
		_bump(tally, "licids a creature again")
	elif line.contains(" to ignore ") and line.ends_with(" this turn"):
		_bump(tally, "Volrath's Curse ignored (special action)")
	elif line.contains("'s hand (buyback)"):
		_bump(tally, "buyback returns to hand")
	elif line.begins_with("A delay counter is removed from ") and line.ends_with("(0 left)"):
		_bump(tally, "delayed spells returned to the stack")
	elif line.contains("'s damage is redirected to "):
		_bump(tally, "damage redirected")
	elif line.contains(" is redirected to ") or line.contains("'s ability is redirected to "):
		_bump(tally, "spells or abilities retargeted")
	elif line.ends_with("(Oath of Druids)"):
		_bump(tally, "Oath of Druids reveals")
	elif line.contains("damage") and (line.contains(" prevents ") \
			or line.contains(" instead") or line.contains(" becomes ")):
		for name in _deck_names:
			if line.begins_with(name):
				_bump(tally, "damage replacements applied")
				_bump(tally, "damage replaced: " + name)
				break
		# A redirect (the en-Kor, Shaman en-Kor, Soltari Guerrillas):
		# "<shield>: <source>'s damage to <victim> is dealt to <other> instead".
		if line.contains(" is dealt to ") and line.ends_with(" instead"):
			_bump(tally, "damage redirected")


func _print_duel(d: Dictionary) -> void:
	var tally: Dictionary = d.tally
	var winner := "none"
	if int(d.winner) >= 0: winner = String(d.decks[int(d.winner)])
	print("PACK 9 AI DUEL %s: %s seed %d %s (%s) vs %s (%s) — winner %s, %d turns, %.1f s; shadow attacks %d, buyback %d, licids %d/%d, sliver grants %d, spike moves %d, oaths %d, refusals %d; errors %d, warnings %d%s" % [
		d.status, d.edition, d.seed, d.decks[0], d.pilots[0], d.decks[1], d.pilots[1],
		winner, d.turns, float(d.ms) / 1000.0,
		int(tally.get("shadow attackers declared", 0)),
		int(tally.get("buyback casts (buyback paid)", 0)),
		int(tally.get("licid activations (became an Aura)", 0)),
		int(tally.get("licid effects ended (special action)", 0)),
		int(tally.get("Sliver attackers with a granted keyword", 0))
			+ int(tally.get("granted Sliver abilities activated", 0)),
		int(tally.get("Spike abilities activated", 0)),
		int(tally.get("Oath triggers", 0)),
		int(tally.get("AI refusals (casts and activations)", 0)),
		d.errors, d.warnings,
		(" — " + String(d.stall)) if String(d.stall) != "" else ""])
	for key in d.refusals:
		if int(d.refusals[key]) >= REFUSAL_LOOP:
			print("PACK 9 REFUSAL LOOP: %s seed %d — %s refused %d times" % [d.edition, d.seed,
				key, int(d.refusals[key])])


func _dump(game: MtgGame, d: Dictionary) -> void:
	printerr("PACK 9 AI AUDIT %s: %s seed %d %s (%s) vs %s (%s), turn %d%s%s" % [d.status, d.edition,
		d.seed, d.decks[0], d.pilots[0], d.decks[1], d.pilots[1], game.turn_number,
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
		print("PACK 9 MECHANIC: %s = %d (%s)" % [key, int(all.get(key, 0)), _split(totals, editions, key)])
	var keys: Array = all.keys().filter(func(k: String) -> bool: return not MECHANICS.has(k))
	keys.sort()
	for key in keys:
		print("PACK 9 ACTUAL USE: %s = %d (%s)" % [key, int(all[key]), _split(totals, editions, key)])
	# The Tempest block cards in these decks that no duel ever cast or
	# played: reported, not failed — a short campaign need not draw everything.
	var block := TempestBlockPack.names()
	var unused: Array[String] = []
	var in_decks := 0
	for name in _deck_names:
		if not block.has(name): continue
		in_decks += 1
		var land := CardRegistry.get_card(name).is_land()
		if int(all.get(("play: " if land else "cast: ") + name, 0)) == 0: unused.append(name)
	unused.sort()
	print("PACK 9 NOT CAST OR PLAYED (%d of %d block names in the decks): %s" % [unused.size(),
		in_decks, ", ".join(PackedStringArray(unused)) if not unused.is_empty() else "none"])
	# Per edition and pilot pairing: duels, completions, the deck results.
	for edition in editions:
		for pairing in ["Wizard v Wizard", "Wizard v Apprentice"]:
			var rows := duels.filter(func(d: Dictionary) -> bool:
				return d.edition == edition and (pairing == "Wizard v Wizard") \
					== (d.pilots[0] == "Wizard" and d.pilots[1] == "Wizard"))
			if rows.is_empty(): continue
			var done := rows.filter(func(d: Dictionary) -> bool: return d.status == "OK").size()
			var stalls := rows.filter(func(d: Dictionary) -> bool: return d.stall != "").size()
			var errs := rows.filter(func(d: Dictionary) -> bool:
				return int(d.errors) + int(d.warnings) > 0).size()
			var apprentice_wins := 0
			for d in rows:
				var w := int(d.winner)
				if w >= 0 and d.pilots[w] == "Apprentice": apprentice_wins += 1
			print("PACK 9 PAIRING: %s %s — %d duels, %d completed cleanly, %d stalled, %d with errors%s" % [
				edition, pairing, rows.size(), done, stalls, errs,
				(", the Apprentice won %d" % apprentice_wins) if pairing != "Wizard v Wizard" else ""])
	var record := {}   # deck -> [wins, games]
	for d in duels:
		for seat in 2:
			var name := String(d.decks[seat])
			if not record.has(name): record[name] = [0, 0]
			record[name][1] += 1
			if int(d.winner) == seat: record[name][0] += 1
	for spec in DECKS:
		if record.has(spec.name):
			print("PACK 9 DECK: %s won %d of %d" % [spec.name, record[spec.name][0], record[spec.name][1]])
	var turns: Array = duels.map(func(d: Dictionary) -> int: return int(d.turns))
	print("PACK 9 DUEL LENGTHS: %d-%d turns over %d duels" % [turns.min(), turns.max(), duels.size()])


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
