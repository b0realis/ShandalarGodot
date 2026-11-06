extends SceneTree
## Deterministic complete Urza block (Pack 10) duels in both rulesets —
## Wizard v Wizard and Wizard v Apprentice — and the evidence that the
## block's mechanics were PLAYED, not merely loaded: casts per card,
## activations per ability, triggers per card, echo paid and let go, cycles
## (and the free ones under Fluctuator), lands an untap spell or ability
## handed back, Opal, Veiled and Hidden enchantments become creatures,
## verse, page and fuse counters cashed, cards entering together (Show and
## Tell, Replenish, Exhume), plays from the graveyard under Yawgmoth's Will
## and from the library's top under Temporal Aperture, Okk, Defensive
## Formation and Outmaneuver in combat, Metalworker's reveals, Storage
## Matrix's choices, Damping Engine ignored, and the block's mana sources —
## plus every refusal the engine handed the AI.
##
## Nine themed 60-card decks (echo aggro, cycling, enchantress, the Opal and
## Veiled family, artifacts and untap mana, the black graveyard, red burn
## and goblins, white weenie, the Legacy and Destiny tricks); each round
## every deck plays the next one in rotation, once Wizard v Wizard and once
## Wizard v Apprentice (the Apprentice alternates seats), so a round is 18
## duels per ruleset, 36 in all.
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
## for the rest of the step. One card refused REFUSAL_LOOP times for one
## reason in one duel is printed as a refusal loop.
##
## Isolation: requires the repository's `shandalar_test` runtime feature
## (tools/runtime.sh `shandalar_test_profile`), enables Pack 10 IN MEMORY
## ONLY (never written to settings) and writes no Elo, no deck, no log file
## of its own. It needs the pack's rules, not its pictures: the real local
## ZIP or the test fixture both serve.
##
##   . tools/runtime.sh; shandalar_find_godot; shandalar_find_timeout
##   shandalar_test_profile
##   export SHANDALAR_PACK_10="$PWD/../shandalar-packs/Pack-10-Urza-Block.zip"
##   "$SHANDALAR_TIMEOUT" -k 5 5400 "$GODOT" --headless --path . \
##       --script res://tools/pack_10_duel_audit.gd -- --rounds 12 --seed 99000 \
##       > audit.log 2>&1 </dev/null

const DEFAULT_SEED := 99000
const DEFAULT_TURN_CAP := 120
## A turn that has not ended after this many seat actions is a loop
## (a {0} ability toggled for ever, a priority ping-pong), not a turn.
const MAX_ACTIONS_PER_TURN := 2000
## The pool with Pack 10 alone: 897 core + 591 new + 18 shared reprints.
const POOL_WITH_PACK_10 := 1506
## The lines of a failed duel's log replayed on stderr.
const FAILURE_LOG_TAIL := 60
## Wizard-v-Apprentice duels draw their seeds this far above the
## Wizard-v-Wizard ones, so the two pairings never share a seed.
const APPRENTICE_SEED_OFFSET := 50000
## One card refused this often for one reason in one duel is reported as
## a refusal loop (the engine said no again and again, step after step).
const REFUSAL_LOOP := 20

## Each deck: its name, its basic and nonbasic lands, its spells. 60 cards.
## Pack 10 and the 1997 core only.
const DECKS := [
	{"name": "Echo", "lands": {"Mountain": 11, "Forest": 11, "Smoldering Crater": 1,
		"Slippery Karst": 1}, "cards": {
		"Goblin War Buggy": 4, "Viashino Outrider": 3, "Albino Troll": 4,
		"Pouncing Jaguar": 4, "Avalanche Riders": 2, "Crater Hellion": 1,
		"Cradle Guard": 2, "Keldon Champion": 2, "Shivan Raptor": 2,
		"Multani's Acolyte": 2, "Simian Grunts": 2, "Rancor": 3, "Goblin Patrol": 2,
		"Hunting Moa": 2, "Deranged Hermit": 1}},
	{"name": "Cycling", "lands": {"Plains": 9, "Island": 9, "Drifting Meadow": 2,
		"Remote Isle": 2}, "cards": {
		"Fluctuator": 3, "Clear": 2, "Disciple of Grace": 2, "Disciple of Law": 2,
		"Miscalculation": 3, "Rescind": 2, "Pendrell Drake": 3, "Sandbar Merfolk": 3,
		"Sandbar Serpent": 2, "Shimmering Barrier": 2, "Iron Will": 2, "Fend Off": 2,
		"Radiant's Judgment": 2, "Drifting Djinn": 2, "Rune of Protection: Red": 1,
		"Rune of Protection: Black": 1, "Veiled Serpent": 2, "Pegasus Charger": 2}},
	{"name": "Enchantress", "lands": {"Forest": 11, "Plains": 10, "Serra's Sanctum": 1}, "cards": {
		"Argothian Enchantress": 4, "Yavimaya Enchantress": 3, "Rancor": 3,
		"Opalescence": 2, "Replenish": 2, "Brilliant Halo": 2, "Fortitude": 2,
		"Cessation": 2, "Glorious Anthem": 2, "Exploration": 2, "Sanctum Guardian": 1,
		"Sanctum Custodian": 2, "Serra's Embrace": 1, "Gaea's Embrace": 1,
		"Retaliation": 1, "War Dance": 2, "Hidden Gibbons": 2, "Hidden Predators": 2,
		"Hidden Stag": 2}},
	{"name": "Opal", "lands": {"Plains": 12, "Island": 11, "Forbidding Watchtower": 1}, "cards": {
		"Opal Acrolith": 2, "Opal Archangel": 2, "Opal Caryatid": 3, "Opal Gargoyle": 3,
		"Opal Titan": 2, "Opal Avenger": 2, "Opal Champion": 2, "Veiled Apparition": 2,
		"Veiled Crocodile": 2, "Veiled Sentry": 3, "Veiled Serpent": 2,
		"Soul Sculptor": 1, "Swords to Plowshares": 2, "Counterspell": 2,
		"Disenchant": 2, "Sustainer of the Realm": 2, "Serra Advocate": 2}},
	{"name": "Artifacts", "lands": {"Island": 20, "Tolarian Academy": 1, "Remote Isle": 1}, "cards": {
		"Grim Monolith": 3, "Voltaic Key": 2, "Metalworker": 2, "Masticore": 2,
		"Thran Dynamo": 2, "Palinchron": 1, "Peregrine Drake": 2, "Great Whale": 1,
		"Worn Powerstone": 2, "Frantic Search": 2, "Snap": 2, "Cloud of Faeries": 3,
		"Tinker": 1, "Basalt Monolith": 1, "Juggernaut": 2, "Thran War Machine": 2,
		"Mishra's Helix": 1, "Temporal Aperture": 1, "Storage Matrix": 1, "Rewind": 2,
		"Morphling": 1, "Copper Gnomes": 2}},
	{"name": "Graveyard", "lands": {"Swamp": 21, "Polluted Mire": 1, "Spawning Pool": 1}, "cards": {
		"Yawgmoth's Will": 2, "Exhume": 2, "Phyrexian Negator": 3, "Corrupt": 2,
		"Yawgmoth's Bargain": 1, "Dark Ritual": 4, "Unearth": 2, "Bone Shredder": 2,
		"Skittering Skirge": 2, "Sanguine Guard": 2, "Phyrexian Ghoul": 2,
		"Order of Yawgmoth": 2, "Duress": 2, "Unnerve": 1, "Expunge": 2,
		"Abyssal Horror": 1, "Dark Hatchling": 1, "Victimize": 1,
		"Apprentice Necromancer": 1, "Raise Dead": 2}},
	{"name": "Burn", "lands": {"Mountain": 20, "Shivan Gorge": 1, "Ghitu Encampment": 1}, "cards": {
		"Arc Lightning": 4, "Shivan Hellkite": 2, "Goblin Lackey": 3, "Sneak Attack": 2,
		"Lightning Bolt": 4, "Flame Jet": 2, "Goblin Matron": 2, "Goblin Raider": 3,
		"Hulking Ogre": 2, "Bloodshot Cyclops": 1, "Heat Ray": 2, "Shower of Sparks": 2,
		"Goblin Marshal": 1, "Torch Song": 2, "Rumbling Crescendo": 1,
		"Lightning Dragon": 2, "Okk": 2, "Outmaneuver": 1}},
	{"name": "White Weenie", "lands": {"Plains": 21, "Forbidding Watchtower": 1}, "cards": {
		"Serra's Liturgy": 2, "Glorious Anthem": 3, "Defensive Formation": 2,
		"Mother of Runes": 3, "Serra Zealot": 4, "Pegasus Charger": 3,
		"Savannah Lions": 4, "White Knight": 3, "Capashen Knight": 2, "Knighthood": 1,
		"Serra's Hymn": 2, "Radiant's Dragoons": 2, "Herald of Serra": 2,
		"Expendable Troops": 2, "Elite Archers": 1, "Swords to Plowshares": 2}},
	{"name": "Tricks", "lands": {"Island": 10, "Forest": 10, "Treetop Village": 1,
		"Faerie Conclave": 1, "Gaea's Cradle": 1}, "cards": {
		"Show and Tell": 3, "Donate": 2, "Gilded Drake": 2, "Treachery": 2,
		"Opposition": 2, "Rofellos, Llanowar Emissary": 2, "Multani, Maro-Sorcerer": 1,
		"Child of Gaea": 1, "Thorn Elemental": 1, "Ancient Silverback": 1,
		"Yavimaya Wurm": 1, "Wild Dogs": 2, "Damping Engine": 1, "Priest of Titania": 2,
		"Llanowar Elves": 2, "Counterspell": 2, "Lilting Refrain": 1, "Windfall": 1,
		"Morphling": 1, "Temporal Aperture": 2, "Snap": 2, "Yavimaya Elder": 2,
		"Multani's Presence": 1}},
]

## The summary keys, so a zero is printed rather than left out.
const MECHANICS := [
	"echo paid", "echo let go",
	"cycling activations", "cycling lands cycled", "cycles under Fluctuator",
	"lands untapped by a spell or ability", "permanents untapped by an ability (not lands)",
	"Opal, Veiled and Hidden enchantments became creatures",
	"enchantment creatures attacking",
	"verse, page and fuse counters cashed", "counters cashed at 0",
	"cards entering together (Show and Tell, Replenish, Exhume)",
	"Show and Tell picks", "graveyard plays under Yawgmoth's Will",
	"library-top plays under Temporal Aperture",
	"Okk attacks", "Okk blocks", "attacks into Defensive Formation", "Outmaneuver casts",
	"Metalworker reveals", "artifacts revealed to Metalworker",
	"Storage Matrix choices", "Damping Engine ignored (special action)",
	"Sneak Attack activations", "Masticore upkeeps paid",
	"nonbasic land mana taps", "mana artifact taps",
	"AI refusals (casts and activations)",
]

## The resolutions that put several cards onto the battlefield at once
## (Pack 10 E10, `MtgGame.put_onto_battlefield_together`).
const TOGETHER_SOURCES := ["Show and Tell", "Replenish", "Exhume", "Planar Birth",
	"Living Death"]

## The counter cards whose sacrifice cashes what they collected.
const COUNTER_CARDS := {"Serra's Liturgy": "verse", "Torch Song": "verse",
	"Rumbling Crescendo": "verse", "War Dance": "verse", "Serra's Hymn": "verse",
	"Vile Requiem": "verse", "Midsummer Revel": "verse", "Discordant Dirge": "verse",
	"Recantation": "verse", "Lilting Refrain": "verse", "Barrin's Codex": "page",
	"Powder Keg": "fuse"}


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
## Card names of every deck, longest first.
var _deck_names: Array[String] = []
## What each seat could play from a zone just before it acted: the ids in
## its graveyard while a Yawgmoth's Will row stood, and its library's top
## while a Temporal Aperture row did ({pid: {"graveyard": {id: true},
## "top": id}}). Read only — so a seed plays the same duel.
var _zone_snapshot := {}


func _initialize() -> void: _run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--version") or args.has("-V"):
		print("pack_10_duel_audit.gd ", ProjectSettings.get_setting("application/config/version", "unknown"))
		quit(0)
		return
	if args.has("--help") or args.has("-h"):
		print("Pack 10 Urza block audit — complete Wizard duels and actual card and mechanic use in both rulesets.")
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
		print("Set SHANDALAR_PACK_10 to your locally built Pack-10-Urza-Block.zip; run with --script res://tools/pack_10_duel_audit.gd.")
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
		printerr("PACK 10 AI AUDIT: requires GODOT_EDITOR_CUSTOM_FEATURES=shandalar_test (tools/runtime.sh shandalar_test_profile)")
		quit(2)
		return
	var packs: Node = root.get_node("CardPacks")
	if not packs.has_pack(UrzaBlockPack.ID):
		printerr("PACK 10 AI AUDIT: no valid Pack-10-Urza-Block.zip found; set SHANDALAR_PACK_10")
		quit(2)
		return
	# In memory only: the third argument keeps the player's (here: the
	# isolated test profile's) settings file untouched.
	Settings.set_value("enabled_card_packs", [UrzaBlockPack.ID], false)
	packs._configure_registry()
	CardRegistry.ensure_loaded()
	if CardRegistry.size() != POOL_WITH_PACK_10:
		printerr("PACK 10 AI AUDIT: expected %d cards with Pack 10 alone, found %d" % [POOL_WITH_PACK_10, CardRegistry.size()])
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
		printerr("PACK 10 AI AUDIT: --only-index selected no duel")
		quit(3)
		return
	_report(duels, totals, editions)
	var failed := duels.filter(func(d: Dictionary) -> bool: return d.status != "OK")
	if failed.is_empty():
		print("PACK 10 AI AUDIT OK: %d completed full duels, no stall, no engine error" % duels.size())
		quit(0)
	else:
		printerr("PACK 10 AI AUDIT FAILED: %d of %d duels — %d stalled, %d logged errors or warnings" % [
			failed.size(), duels.size(),
			duels.filter(func(d: Dictionary) -> bool: return d.stall != "").size(),
			duels.filter(func(d: Dictionary) -> bool: return int(d.errors) + int(d.warnings) > 0).size()])
		quit(2)


## Every deck as a 60-name list, or [] after naming every problem.
func _build_decks() -> Array:
	var out: Array = []
	var problems: Array[String] = []
	var names := {}
	# Pack 10 alone is enabled, so the registry holds the core and the block
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
	for why in problems: printerr("PACK 10 AI AUDIT: " + why)
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
	var names := ["Urza " + String(DECKS[i].name), "Urza " + String(DECKS[opponent].name)]
	game.setup(decks[i], decks[opponent], names[0], names[1], 20, 20, duel_seed)
	game.rules.set_edition(edition)
	var a := AiPlayer.new(0, AiProfile.apprentice() if apprentice_seat == 0 else AiProfile.wizard())
	var b := AiPlayer.new(1, AiProfile.apprentice() if apprentice_seat == 1 else AiProfile.wizard())
	game.set_agent(0, a)
	game.set_agent(1, b)
	var tally := {}
	_zone_snapshot = {}
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
	_read_choices(game, tally)
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
## (so a seed plays the same duel), with the audit's stricter stall rules
## and a read-only look at the zone-play rows before each seat acts.
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
		_snapshot_zones(game)
		if a.act(game) == "":
			_snapshot_zones(game)
			if b.act(game) == "" and not game.game_over:
				return "neither seat could act at %s, turn %d" % [
					Mtg.step_name(game.current_step()), game.turn_number]
		in_turn += 1
	return ""


## Which cards each seat could play from its graveyard or its library's
## top right now (only while a zone-play row stands — Yawgmoth's Will,
## Temporal Aperture). Reads, never writes.
func _snapshot_zones(game: MtgGame) -> void:
	_zone_snapshot = {}
	for pid in game.players.size():
		var player: MtgPlayer = game.players[pid]
		if player.graveyard_cast_permissions.is_empty():
			continue
		var ids := {}
		for card in player.graveyard: ids[card.id] = true
		_zone_snapshot[pid] = {"graveyard": ids,
			"top": player.library.back().id if not player.library.is_empty() else -1}


## A card [param pid] just played or cast: from where the snapshot says it
## lay — "graveyard", "top" or "".
func _played_from(pid: int, inst: CardInstance) -> String:
	if inst == null or not _zone_snapshot.has(pid): return ""
	var snap: Dictionary = _zone_snapshot[pid]
	if (snap["graveyard"] as Dictionary).has(inst.id): return "graveyard"
	if int(snap["top"]) == inst.id: return "top"
	return ""


## The events the log does not spell out: how each spell was cast (from
## the graveyard, the library's top), cycling, lands handed back by an
## untap, enchantment creatures and Okk in combat, attacks into Defensive
## Formation, counters cashed, cards entering together, and mana from the
## block's lands and artifacts.
func _on_event(event: GameEvent, game: MtgGame, tally: Dictionary) -> void:
	var data: Dictionary = event.data
	match event.type:
		Mtg.EventType.DECLARED_ATTACKERS:
			var attackers: Array = data.get("attackers", [])
			for attacker in attackers:
				var inst := attacker as CardInstance
				if inst == null: continue
				if inst.is_type(Mtg.CardType.ENCHANTMENT):
					_bump(tally, "enchantment creatures attacking")
					_bump(tally, "enchantment creature attacked: " + inst.data.card_name)
				if inst.data.card_name == "Okk":
					_bump(tally, "Okk attacks")
			if not attackers.is_empty():
				var defender := game.opponent_of(game.active_player)
				for inst in game.players[defender].battlefield:
					if inst.data.card_name == "Defensive Formation":
						_bump(tally, "attacks into Defensive Formation")
						break
		Mtg.EventType.BLOCKED:
			var blocker: CardInstance = data.get("blocker")
			if blocker != null and blocker.data.card_name == "Okk":
				_bump(tally, "Okk blocks")
		Mtg.EventType.SPELL_CAST:
			_on_cast(game, data, tally)
		Mtg.EventType.LAND_PLAYED:
			var land: CardInstance = data.get("instance")
			match _played_from(int(data.get("controller", -1)), land):
				"graveyard":
					_bump(tally, "graveyard plays under Yawgmoth's Will")
					_bump(tally, "graveyard play: land " + land.data.card_name)
				"top":
					_bump(tally, "library-top plays under Temporal Aperture")
					_bump(tally, "library-top play: land " + land.data.card_name)
		Mtg.EventType.ABILITY_ACTIVATED:
			var source: CardInstance = data.get("instance")
			var ability: Variant = data.get("ability")
			if source == null or not (ability is ActivatedAbility): return
			var activated := ability as ActivatedAbility
			if activated.is_cycling or activated.activation_zone == Mtg.Zone.HAND:
				_bump(tally, "cycling activations")
				_bump(tally, "cycled: " + source.data.card_name)
				if source.data.is_land():
					_bump(tally, "cycling lands cycled")
				var who := int(data.get("player", source.owner_id))
				for inst in game.players[who].battlefield:
					if inst.data.card_name == "Fluctuator":
						_bump(tally, "cycles under Fluctuator")
						break
			var kind := String(COUNTER_CARDS.get(source.data.card_name, ""))
			if kind != "":
				var counters: Dictionary = source.counters \
					if source.zone == Mtg.Zone.BATTLEFIELD else source.last_counters
				var n := int(counters.get(kind, 0))
				_bump(tally, "verse, page and fuse counters cashed")
				_bump(tally, "cashed: %s at %d %s" % [source.data.card_name, n, kind])
				if n == 0: _bump(tally, "counters cashed at 0")
			if source.data.card_name == "Sneak Attack":
				_bump(tally, "Sneak Attack activations")
		Mtg.EventType.BECAME_UNTAPPED:
			var thing: CardInstance = data.get("instance")
			if thing == null or game.current_step() == Mtg.Step.UNTAP: return
			var by := game.current_resolution_source()
			if thing.is_land():
				_bump(tally, "lands untapped by a spell or ability")
				_bump(tally, "land untap: by " + (by if by != "" else "an ability"))
			elif by != "":
				_bump(tally, "permanents untapped by an ability (not lands)")
				_bump(tally, "untap: %s by %s" % [thing.data.card_name, by])
		Mtg.EventType.ENTERS_BATTLEFIELD:
			var entered: CardInstance = data.get("instance")
			if entered == null: return
			var by := game.current_resolution_source()
			if TOGETHER_SOURCES.has(by):
				_bump(tally, "cards entering together (Show and Tell, Replenish, Exhume)")
				_bump(tally, "together: %s by %s" % [entered.data.card_name, by])
			if entered.data.is_land() and (entered.data.supertypes & Mtg.Supertype.BASIC) == 0:
				_bump(tally, "land entered: " + entered.data.card_name)
		Mtg.EventType.TAPPED_FOR_MANA:
			var land: CardInstance = data.get("instance")
			if land != null and land.is_land() and (land.data.supertypes & Mtg.Supertype.BASIC) == 0:
				_bump(tally, "nonbasic land mana taps")
				_bump(tally, "mana: %s tapped" % land.data.card_name)
		Mtg.EventType.BECAME_TAPPED:
			var thing: CardInstance = data.get("instance")
			if thing != null and not thing.is_land() and not thing.is_creature() \
					and not thing.data.mana_abilities.is_empty():
				_bump(tally, "mana artifact taps")
				_bump(tally, "mana: %s tapped" % thing.data.card_name)


## A spell was cast: from where (the graveyard under Yawgmoth's Will, the
## library's top under Temporal Aperture) and the one-offs the summary
## counts by name.
func _on_cast(game: MtgGame, data: Dictionary, tally: Dictionary) -> void:
	var inst: CardInstance = data.get("instance")
	if inst == null: return
	var card := inst.data
	match _played_from(int(data.get("controller", -1)), inst):
		"graveyard":
			_bump(tally, "graveyard plays under Yawgmoth's Will")
			_bump(tally, "graveyard play: " + card.card_name)
		"top":
			_bump(tally, "library-top plays under Temporal Aperture")
			var item := game.find_stack_item(inst)
			var free := item != null and item.description.contains("(Temporal Aperture)")
			_bump(tally, "library-top play: %s%s" % [card.card_name, " (free)" if free else ""])
	if card.card_name == "Outmaneuver":
		_bump(tally, "Outmaneuver casts")


## The log's own record: casts, activations (per ability), triggers (per
## card), plays of nonbasic lands, echo paid and let go, Opal-family
## creatures, Show and Tell picks, Metalworker's reveals, Damping Engine
## ignored, Masticore's upkeep, and the AI's refused tries. Returns the
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
			_:
				_read_plain_line(line, tally, refusals)
	for key in refusals:
		_bump(tally, "AI refusals (casts and activations)", int(refusals[key]))
		_bump(tally, "AI refused: " + String(key), int(refusals[key]))
	return refusals


## One log line without a kind of its own (or with one the audit does not
## read): the block's own sentences.
func _read_plain_line(line: String, tally: Dictionary, refusals: Dictionary) -> void:
	if line.begins_with("(AI cast of ") or line.begins_with("(AI activation of "):
		var key := line.trim_prefix("(AI cast of ").trim_prefix("(AI activation of ") \
			.trim_suffix(")").replace(" refused: ", ": ")
		key = _short(key)
		refusals[key] = int(refusals.get(key, 0)) + 1
		return
	if line.contains(" pays echo for "):
		_bump(tally, "echo paid")
		_bump(tally, "echo paid: " + line.get_slice(" pays echo for ", 1))
	elif line.contains(" doesn't pay echo for "):
		_bump(tally, "echo let go")
		_bump(tally, "echo let go: " + line.get_slice(" doesn't pay echo for ", 1))
	elif line.contains(" becomes a ") and line.ends_with(" creature"):
		var who := line.get_slice(" becomes a ", 0)
		if who.begins_with("Opal ") or who.begins_with("Veiled ") or who.begins_with("Hidden ") \
				or who == "Lurking Evil":
			_bump(tally, "Opal, Veiled and Hidden enchantments became creatures")
			_bump(tally, "became a creature: " + who)
	elif line.ends_with(" for Show and Tell"):
		_bump(tally, "Show and Tell picks")
		_bump(tally, "Show and Tell: " + line.get_slice(" chooses ", 1).trim_suffix(" for Show and Tell"))
	elif line.ends_with("(Metalworker)") and line.contains(" reveals "):
		_bump(tally, "Metalworker reveals")
		var shown := line.get_slice(" reveals ", 1).trim_suffix(" (Metalworker)")
		_bump(tally, "artifacts revealed to Metalworker", shown.split(", ").size())
	elif line.contains(" to ignore Damping Engine this turn"):
		_bump(tally, "Damping Engine ignored (special action)")


## The questions the duel put (MtgGame.choice_log): Storage Matrix's kind
## each untap step, Masticore's upkeep discard, and every Pack 10 card's
## yes/no or option answer, by source.
func _read_choices(game: MtgGame, tally: Dictionary) -> void:
	for choice: PlayerChoice in game.choice_log:
		var source := choice.source
		if source == "Storage Matrix" and choice.kind == PlayerChoice.Kind.OPTION:
			_bump(tally, "Storage Matrix choices")
			var picked := int(choice.answer) if choice.answer is int else -1
			if picked >= 0 and picked < choice.options.size():
				_bump(tally, "Storage Matrix: " + String(choice.options[picked]))
		elif source == "Masticore" and choice.kind == PlayerChoice.Kind.YES_NO \
				and bool(choice.answer):
			_bump(tally, "Masticore upkeeps paid")


func _print_duel(d: Dictionary) -> void:
	var tally: Dictionary = d.tally
	var winner := "none"
	if int(d.winner) >= 0: winner = String(d.decks[int(d.winner)])
	print("PACK 10 AI DUEL %s: %s seed %d %s (%s) vs %s (%s) — winner %s, %d turns, %.1f s; echo %d/%d, cycles %d, untapped lands %d, opals %d, counters cashed %d, together %d, will %d, aperture %d, refusals %d; errors %d, warnings %d%s" % [
		d.status, d.edition, d.seed, d.decks[0], d.pilots[0], d.decks[1], d.pilots[1],
		winner, d.turns, float(d.ms) / 1000.0,
		int(tally.get("echo paid", 0)), int(tally.get("echo let go", 0)),
		int(tally.get("cycling activations", 0)),
		int(tally.get("lands untapped by a spell or ability", 0)),
		int(tally.get("Opal, Veiled and Hidden enchantments became creatures", 0)),
		int(tally.get("verse, page and fuse counters cashed", 0)),
		int(tally.get("cards entering together (Show and Tell, Replenish, Exhume)", 0)),
		int(tally.get("graveyard plays under Yawgmoth's Will", 0)),
		int(tally.get("library-top plays under Temporal Aperture", 0)),
		int(tally.get("AI refusals (casts and activations)", 0)),
		d.errors, d.warnings,
		(" — " + String(d.stall)) if String(d.stall) != "" else ""])
	for key in d.refusals:
		if int(d.refusals[key]) >= REFUSAL_LOOP:
			print("PACK 10 REFUSAL LOOP: %s seed %d — %s refused %d times" % [d.edition, d.seed,
				key, int(d.refusals[key])])


func _dump(game: MtgGame, d: Dictionary) -> void:
	printerr("PACK 10 AI AUDIT %s: %s seed %d %s (%s) vs %s (%s), turn %d%s%s" % [d.status, d.edition,
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
		print("PACK 10 MECHANIC: %s = %d (%s)" % [key, int(all.get(key, 0)), _split(totals, editions, key)])
	var keys: Array = all.keys().filter(func(k: String) -> bool: return not MECHANICS.has(k))
	keys.sort()
	for key in keys:
		print("PACK 10 ACTUAL USE: %s = %d (%s)" % [key, int(all[key]), _split(totals, editions, key)])
	# The Urza block cards in these decks that no duel ever cast or played:
	# reported, not failed — a short campaign need not draw everything.
	var block := UrzaBlockPack.names()
	var unused: Array[String] = []
	var in_decks := 0
	for name in _deck_names:
		if not block.has(name): continue
		in_decks += 1
		var land := CardRegistry.get_card(name).is_land()
		if int(all.get(("play: " if land else "cast: ") + name, 0)) == 0: unused.append(name)
	unused.sort()
	print("PACK 10 NOT CAST OR PLAYED (%d of %d block names in the decks): %s" % [unused.size(),
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
			print("PACK 10 PAIRING: %s %s — %d duels, %d completed cleanly, %d stalled, %d with errors%s" % [
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
			print("PACK 10 DECK: %s won %d of %d" % [spec.name, record[spec.name][0], record[spec.name][1]])
	var turns: Array = duels.map(func(d: Dictionary) -> int: return int(d.turns))
	print("PACK 10 DUEL LENGTHS: %d-%d turns over %d duels" % [turns.min(), turns.max(), duels.size()])


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
