extends SceneTree
## THE DUEL SOAK — whole duels played THROUGH THE LIVE DUEL SCREEN, several
## in a row, with the engine's errors counted. Run it with `./duel_soak.sh`
## (see the manual there); this file is the part that plays.
##
##   xvfb-run -a timeout -k 5 900 ../tools/godot --path . \
##       -s res://tools/duel_soak.gd -- --mode both --count 3
##
## WHY THIS EXISTS. The test suite drives the engine, and the UI tests
## drive one widget at a time; nothing had ever watched an entire duel go
## through `DuelScreen` itself — the coin toss, the opening window, every
## refresh, every spell flight, the end-of-duel window — with Godot's
## error stream in view. The first time something did (2026-09-02) it
## found two bugs in three duels that 3180 green tests had not: a
## re-routed spell flight firing a lambda on a freed ghost, and an
## anchors warning printed once per duel. This is that probe, kept.
##
## TWO WAYS TO PLAY A SEAT:
##
##  * `demo` — both seats are the screen's own AI, exactly as the title
##    screen's demo runs them. Covers every AI-driven path and the
##    presentation around it.
##  * `human` — seat 0 is a HUMAN seat (hidden opponent hand, prompts,
##    targeting cursor, the declarations, the discard and the damage
##    division) driven by [HumanClicker], which touches NOTHING but the
##    handlers the screen's own widgets call: `_on_card_clicked`,
##    `_on_life_clicked`, `_on_done`, `_on_cancel`, the dialogs' own
##    buttons. It plays at random and plays badly, and that is the point:
##    it is a fuzzer for the human seat's paths, not a player. Every
##    decision is drawn from a seeded RNG, so a failure replays.
##
## The engine is untouched by either driver: the demo's AI goes through
## the screen's pacing timer, and the clicker goes through the screen's
## handlers. No `game.` call is made here except to READ state.
##
## EXIT CODES: 0 when every duel reached game over; 2 when a duel stood
## still for [member stall_seconds] (a stuck prompt is the failure this
## mode exists to catch) or never started its game at all; 3 for a bad
## argument — and a value that is not a number IS a bad argument
## (`--stall abc` used to parse to 0 and stall on the second frame).
## Errors and warnings are Godot's own, on stderr, and `duel_soak.sh` is
## what counts them.
##
## THE RULES FORKS come from `user://settings.cfg`, exactly as a player's
## duel gets them — which means a soak on a machine whose Options say
## "modern" never plays the 1997 damage-prevention window at all.
## `--rules fifth|modern` overrides every fork IN MEMORY for the run
## (`Settings.set_value(..., persist=false)`), and the soak puts the
## player's values back before it quits; should anything have persisted
## the file in between (nothing the clicker does can), the restore is
## written through too, so the player's file is never left changed.

## Every shipped deck gets a turn on each side, rotated by duel index.
const DECK_DIR := "res://decks"
const CLICK_SECONDS := 0.05

var mode := "both"
var count := 3
var seeds: Array[int] = []
var stall_seconds := 240.0
var pace := 0.02
var verbose := false
## "" keeps whatever `user://settings.cfg` says; "fifth" / "modern" sets
## every fork to that edition for the run (see the file comment).
var rules_edition := ""

## A screen whose `_ready` never reaches `game = MtgGame.new()` would sit
## with `game == null` until the whole-run guard; this is the bound on it.
const NO_GAME_SECONDS := 30.0

var _plan: Array = []        # [{seed, human}] in play order
var _index := -1
var _duel: Node = null
var _clicker: HumanClicker = null
var _started := 0.0
var _last_signature := ""
var _last_change := 0.0
var _click_clock := 0.0
var _results: Array[String] = []
## The player's own fork values, to put back — see [method _apply_rules].
var _saved_rules := {}
var _exit_code := 3


func _init() -> void:
	if not _parse_args():
		quit(_exit_code)
		return
	# Before anything can click: the file as the player left it.
	_settings_before = snapshot_settings()
	var deck_files := _deck_files()
	if deck_files.is_empty():
		push_error("duel soak: no .deck files under %s" % DECK_DIR)
		quit(3)
		return
	for i in seeds.size():
		if mode == "demo" or mode == "both":
			_plan.append({"seed": seeds[i], "human": false})
		if mode == "human" or mode == "both":
			_plan.append({"seed": seeds[i], "human": true})
	_apply_rules()
	print("SOAK plan: %d duel(s), mode %s, seeds %s%s" % [_plan.size(), mode, seeds,
		"" if rules_edition == "" else ", rules " + rules_edition])
	_next.call_deferred()


func _parse_args() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg: String = args[i]
		var value := ""
		if i + 1 < args.size():
			value = args[i + 1]
		match arg:
			"--mode":
				mode = value
				i += 1
			"--count":
				if not value.is_valid_int() or int(value) < 1:
					return _bad_argument("--count takes a whole number >= 1, not '%s'" % value)
				count = int(value)
				i += 1
			"--seeds":
				for part in value.split(",", false):
					if not part.is_valid_int():
						return _bad_argument("--seeds takes whole numbers, not '%s'" % part)
					seeds.append(int(part))
				i += 1
			"--stall":
				if not value.is_valid_float() or float(value) <= 0.0:
					return _bad_argument("--stall takes seconds > 0, not '%s'" % value)
				stall_seconds = float(value)
				i += 1
			"--pace":
				if not value.is_valid_float() or float(value) < 0.0:
					return _bad_argument("--pace takes seconds >= 0, not '%s'" % value)
				pace = float(value)
				i += 1
			"--rules":
				if not ["fifth", "modern"].has(value.to_lower()):
					return _bad_argument("--rules takes fifth or modern, not '%s'" % value)
				rules_edition = value.to_lower()
				i += 1
			"--verbose":
				verbose = true
			"--help", "-h":
				print(_usage())
				_exit_code = 0
				return false
			_:
				push_error("duel soak: unknown argument %s\n%s" % [arg, _usage()])
				return false
		i += 1
	if not ["demo", "human", "both"].has(mode):
		return _bad_argument("--mode must be demo, human or both")
	if seeds.is_empty():
		# Fixed seeds, so a plain run is the same run every time.
		for n in maxi(count, 1):
			seeds.append(1000 + n * 37)
	return true


func _bad_argument(why: String) -> bool:
	push_error("duel soak: %s\n%s" % [why, _usage()])
	return false


static func _usage() -> String:
	return """duel_soak.gd -- [--mode demo|human|both] [--count N] [--seeds a,b,c]
             [--stall SECONDS] [--pace SECONDS] [--rules fifth|modern]
  --mode    which seats to fuzz (default both: every seed twice)
  --count   how many seeds when --seeds is not given (default 3)
  --seeds   explicit RNG seeds, comma-separated (a failure replays from its seed)
  --stall   seconds a duel may stand still before it counts as stuck (240)
  --pace    the AI's pacing delay (0.02; the demo default is 0.8)
  --rules   play every rules fork as fifth (1997) or modern for this run,
            instead of whatever the Options screen saved (the player's
            settings file is left as it was)
  --verbose print each duel's whole game log after it ends
Exit 0: every duel finished. 2: a duel stood still for --stall seconds, or
never started. 3: a bad argument (a non-number is a bad argument)."""


## `--rules`: every fork to one edition, IN MEMORY — the duel screen reads
## `Settings.rule(key)` at each duel's start, and this is the same door
## the Options screen uses, so the soak plays what a player who chose
## that preset would play. Nothing is persisted (`persist = false`), and
## [method _restore_rules] puts the player's values back at the end.
func _apply_rules() -> void:
	if rules_edition == "":
		return
	var wanted := RulesOptions.new()
	wanted.set_edition(rules_edition)
	for fork in RulesOptions.FORKS:
		var key: String = "rule_" + fork["key"]
		_saved_rules[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.set_value(key, wanted.get_fork(fork["key"]), false)


## THE WHOLE SETTINGS FILE, byte for byte, before the fuzzer touches it.
##
## `_restore_rules` guards the seven RULE keys, which is what `--rules`
## writes. It is not enough: the soak's human seat is a FUZZER clicking
## through the live duel screen, and that screen carries the Dueling
## Options panel — so a run can flip any option a player owns and leave it
## flipped. One did, on 2026-09-03: a soak left `PlayerTerritoryColor="Red"`
## in the file, which changed the owner's own game and then failed a test
## that asserts the shipped default. A tool that reports on the game must
## not change it.
var _settings_before: Variant = null


static func snapshot_settings() -> Variant:
	if not FileAccess.file_exists(Settings.PATH):
		return null      # no file is a state too, and must be restorable
	return FileAccess.get_file_as_string(Settings.PATH)


## Put [param before] back if anything moved. Returns true when it had to.
static func restore_settings(before: Variant) -> bool:
	var now: Variant = null
	if FileAccess.file_exists(Settings.PATH):
		now = FileAccess.get_file_as_string(Settings.PATH)
	if now == before:
		return false
	if before == null:
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(Settings.PATH))
		Settings.reload()
		return true
	var file := FileAccess.open(Settings.PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(String(before))
	file.close()
	# The file is the player's again; memory has to agree, or the next
	# reader in this process answers with what the fuzzer wrote.
	Settings.reload()
	return true


## The player's fork values back where they were — but only when they
## need to be: `_apply_rules` marked the settings dirty and nothing the
## soak does writes them, so `is_dirty` still true means the file never
## changed and memory dies with the process. Should something have
## written it (`is_dirty` false), the player's values go through to the
## file, so a soak can never leave `user://settings.cfg` saying what
## `--rules` said.
func _restore_rules() -> void:
	# The file first, because it covers everything a fuzzer can reach; the
	# fork-by-fork restore below is the in-memory half of the same promise.
	if restore_settings(_settings_before):
		print("SOAK note: the run changed user://settings.cfg; it was put back")
	if _saved_rules.is_empty():
		return
	if not Settings.is_dirty():
		for key in _saved_rules:
			if _saved_rules[key] == null:
				Settings.clear_value(key)
			else:
				Settings.set_value(key, _saved_rules[key])
		print("SOAK note: the settings file was written during the run; the player's rules forks were restored to it")
	_saved_rules.clear()


static func _deck_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(DECK_DIR)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".deck"):
			files.append(DECK_DIR.path_join(entry))
		entry = dir.get_next()
	files.sort()
	return files


func _next() -> void:
	if _duel != null:
		root.remove_child(_duel)
		_duel.free()
		_duel = null
		_clicker = null
	_index += 1
	if _index >= _plan.size():
		_restore_rules()
		print("SOAK done: %d duel(s) finished" % _results.size())
		for line in _results:
			print("  " + line)
		quit(0)
		return
	var step: Dictionary = _plan[_index]
	var seed_value: int = step["seed"]
	var human: bool = step["human"]
	var config: DuelConfig
	if human:
		config = DuelConfig.vs_ai_default(AiProfile.wizard())
	else:
		config = DuelConfig.demo_default()
	config.pace = pace
	config.rng_seed = seed_value
	var files := _deck_files()
	var a: int = _index % files.size()
	var b: int = (_index * 3 + 1) % files.size()
	if b == a:
		b = (b + 1) % files.size()
	config.decks = [DeckList.load_file(files[a]).cards, DeckList.load_file(files[b]).cards]
	config.player_names = [files[a].get_file(), files[b].get_file()]
	config.apply_deck_colors()
	_duel = load("res://game/duel/duel_screen.tscn").instantiate()
	_duel.config = config
	_duel.duel_finished.connect(_on_finished)
	if human:
		_clicker = HumanClicker.new(_duel, seed_value)
		_clicker.verbose = verbose
	_started = _now()
	_last_change = _started
	_last_signature = ""
	root.add_child(_duel)
	print("SOAK %s seed %d starts: %s vs %s" % [
		"human" if human else "demo", seed_value,
		files[a].get_file(), files[b].get_file()])


func _on_finished(winner_id: int) -> void:
	var game: MtgGame = _duel.game
	var step: Dictionary = _plan[_index]
	var line := "SOAK %s seed %d: winner %d (%s) after %d turns, life %d/%d, %.1fs" % [
		"human" if step["human"] else "demo", step["seed"], winner_id,
		"draw" if winner_id < 0 else game.players[winner_id].player_name,
		game.turn_number, game.players[0].life, game.players[1].life,
		_now() - _started]
	if _clicker != null:
		line += ", %d clicks" % _clicker.clicks
	print(line)
	_results.append(line)
	if verbose:
		for entry in game.log_lines:
			print("    | " + str(entry))
	# Let the end-of-duel window come up and draw, then press its button.
	for _round in 40:
		await create_timer(0.1).timeout
		if _duel == null or _duel._over_dialog != null:
			break
	if _duel != null and _duel._over_dialog != null:
		_duel._on_game_over_dismissed()
	await create_timer(0.3).timeout
	_next()


func _process(delta: float) -> bool:
	if _duel == null:
		return false
	var now := _now()
	if _duel.game == null:
		# `_ready` builds the game synchronously, so this is a screen whose
		# `_ready` died before it got there; bounded, not left to the
		# whole-run guard.
		if now - _started > NO_GAME_SECONDS:
			var step: Dictionary = _plan[_index]
			print("SOAK STALL: %s seed %d never started its game in %.0fs" % [
				"human" if step["human"] else "demo", step["seed"], now - _started])
			_restore_rules()
			quit(2)
		return false
	var signature := _signature()
	if signature != _last_signature:
		_last_signature = signature
		_last_change = now
	if now - _last_change > stall_seconds:
		var step: Dictionary = _plan[_index]
		print("SOAK STALL: %s seed %d stood still for %.0fs at %s" % [
			"human" if step["human"] else "demo", step["seed"],
			now - _last_change, signature])
		_restore_rules()
		quit(2)
		return false
	if _clicker != null and not _duel.game.game_over:
		_click_clock += delta
		if _click_clock >= CLICK_SECONDS:
			_click_clock = 0.0
			_clicker.tick()
	return false


## What "standing still" is measured against: not the turn number alone,
## since a duel can sit in one turn legitimately for a while, but the
## whole of what the player would see change.
func _signature() -> String:
	var game: MtgGame = _duel.game
	return "turn %d step %d priority %d stack %d mode %d toss %s hands %d/%d" % [
		game.turn_number, game.current_step(), game.priority_player, game.stack.size(),
		_duel.mode, str(_duel._toss_active),
		game.players[0].hand.size(), game.players[1].hand.size()]


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ================================================== THE HUMAN CLICKER --

## Plays seat 0 the way a hand on the mouse would, through the screen's
## own click handlers and nothing else — see the file comment. Every
## decision is random and seeded. It does not try to win.
class HumanClicker:
	const SEAT := 0
	## How many actions to attempt in one priority window before passing —
	## a refused cast is a refused cast, not a reason to click forever.
	const TRIES_PER_WINDOW := 4

	var duel: DuelScreen
	var rng := RandomNumberGenerator.new()
	var clicks := 0
	var verbose := false
	var _window_signature := ""
	var _tries := 0
	var _mulligans := 0

	func _init(p_duel: DuelScreen, seed_value: int) -> void:
		duel = p_duel
		rng.seed = seed_value

	var _seen_mode := -1

	func tick() -> void:
		var game: MtgGame = duel.game
		if game == null or game.game_over or duel._over_dialog != null:
			return
		if verbose and duel.mode != _seen_mode:
			_seen_mode = duel.mode
			print("    > turn %d step %d: mode %d (awaiting attackers %s, active %d)" % [
				game.turn_number, game.current_step(), duel.mode,
				str(game.awaiting_attackers), game.active_player])
		if duel._toss_active:
			_tick_opening()
			return
		if game.awaiting_choice != null:
			_tick_choice(game.awaiting_choice)
			return
		match duel.mode:
			DuelScreen.Mode.TARGETING:
				_tick_targeting()
			DuelScreen.Mode.ATTACKERS:
				_tick_attackers()
			DuelScreen.Mode.BLOCKERS:
				_tick_blockers()
			DuelScreen.Mode.DISCARD:
				_tick_discard()
			DuelScreen.Mode.DAMAGE:
				_tick_damage()
			DuelScreen.Mode.PAYING:
				_tick_paying()
			_:
				_tick_normal()

	# -- the opening window: play or draw, then the mulligan offer --
	func _tick_opening() -> void:
		var window: Node = duel.find_child("OpeningWindow", true, false)
		if window == null or not (window as Control).is_visible_in_tree():
			return
		var labels: PackedStringArray = window.button_labels()
		if labels.is_empty():
			return
		var pick := ""
		if labels.has(OpeningHand.MULLIGAN["take"]) and _mulligans < 1 \
				and rng.randf() < 0.5:
			pick = OpeningHand.MULLIGAN["take"]
			_mulligans += 1
		elif labels.has(OpeningHand.PLAY_OR_DRAW["play_first"]):
			pick = OpeningHand.PLAY_OR_DRAW["play_first"] if rng.randf() < 0.7 \
				else OpeningHand.PLAY_OR_DRAW["draw_first"]
		elif labels.has(OpeningHand.MULLIGAN["start"]):
			pick = OpeningHand.MULLIGAN["start"]
		else:
			pick = labels[0]
		if window.press(pick):
			clicks += 1

	# -- a question the engine holds a resolution open for (§1.3) --
	func _tick_choice(choice: PlayerChoice) -> void:
		if choice.pid != SEAT:
			return
		var labels: Array = DuelScreen.choice_options(choice)
		if labels.is_empty():
			return
		var index := rng.randi_range(0, labels.size() - 1)
		if choice.kind == PlayerChoice.Kind.DISCARD:
			# Pick lines not yet ticked, so the pick count only ever rises.
			var open: Array[int] = []
			for i in labels.size():
				if not duel._choice_picks.has(i):
					open.append(i)
			if open.is_empty():
				return
			index = open[rng.randi_range(0, open.size() - 1)]
		duel._on_choice_option(index)
		clicks += 1

	# -- targeting: one legal target per tick, or Done, or Cancel --
	func _tick_targeting() -> void:
		var game: MtgGame = duel.game
		if duel._pending_card == null or duel._pending_slot >= duel._pending_slots.size():
			duel._on_cancel()
			clicks += 1
			return
		var slot: Dictionary = duel._pending_slots[duel._pending_slot]
		var spec: TargetSpec = slot["spec"]
		var group: Array = duel._pending_groups[duel._pending_slot]
		var want_min := int(slot["min"])
		var want_max := int(slot["max"])
		var divided := int(slot["divided"])
		var candidates: Array = spec.legal_targets(game, duel._pending_card)
		if divided <= 0:
			var fresh: Array = []
			for ref in candidates:
				var taken := false
				for chosen in group:
					if chosen.same_object(ref):
						taken = true
						break
				if not taken:
					fresh.append(ref)
			candidates = fresh
		var satisfied := group.size() >= want_min
		# A variable-count slot is sometimes closed early, to walk the Done
		# path as well as the fill-it-up path.
		var stop_early := satisfied and want_max < 0 and rng.randf() < 0.3
		if candidates.is_empty() or stop_early:
			if satisfied:
				duel._on_done()
			else:
				duel._on_cancel()
			clicks += 1
			return
		_click_ref(candidates[rng.randi_range(0, candidates.size() - 1)])

	## Deliver a target the way the widget for it would: a card on the
	## table or in a hand is a card click, a player is a life-register
	## click, and the rest (graveyard cards, chain abilities, damage
	## markers) arrive by the same call their own widgets make.
	func _click_ref(ref: TargetRef) -> void:
		clicks += 1
		if ref.is_player:
			duel._on_life_clicked(ref.player_id)
			return
		if ref.is_ability or ref.is_damage:
			duel._try_take_target(ref)
			return
		var inst: CardInstance = duel.game.find_instance(ref.instance_id)
		if inst != null and (inst.zone == Mtg.Zone.BATTLEFIELD or inst.zone == Mtg.Zone.HAND):
			duel._on_card_clicked(inst)
		else:
			duel._try_take_target(ref)

	# -- the declarations: every eligible creature is a coin flip --
	func _tick_attackers() -> void:
		var game: MtgGame = duel.game
		var defender := game.opponent_of(game.active_player)
		for inst in game.players[SEAT].battlefield.duplicate():
			if not inst.is_creature() or duel._selected_attackers.has(inst.id):
				continue
			var why := CombatState.attack_illegality(game, inst, defender)
			var skip := rng.randf() < 0.15
			if verbose:
				print("    > attacker %s: %s%s" % [inst.data.card_name,
					"ok" if why == "" else why, " (held back)" if skip else ""])
			if why != "" or skip:
				continue
			duel._on_card_clicked(inst)
			clicks += 1
		duel._on_done()
		clicks += 1

	func _tick_blockers() -> void:
		var game: MtgGame = duel.game
		var attackers: Array = game.combat.attackers.keys()
		if not attackers.is_empty():
			for blocker in game.players[SEAT].battlefield.duplicate():
				if not blocker.is_creature() or duel._block_map.has(blocker.id):
					continue
				if rng.randf() < 0.4:
					continue
				var attacker: CardInstance = game.find_instance(
					attackers[rng.randi_range(0, attackers.size() - 1)])
				if attacker == null:
					continue
				if CombatState.block_illegality(game, blocker, attacker, SEAT) != "":
					continue
				duel._on_card_clicked(blocker)    # pick it up
				duel._on_card_clicked(attacker)   # set it against this one
				clicks += 2
		duel._on_done()
		clicks += 1

	# -- the discard phase (§1.1): fill the count, then Done --
	func _tick_discard() -> void:
		var game: MtgGame = duel.game
		var hand: Array = game.players[SEAT].hand
		var open: Array = []
		for inst in hand:
			if not duel._discard_picks.has(inst.id):
				open.append(inst)
		if duel._discard_picks.size() < game.discard_count and not open.is_empty():
			duel._on_card_clicked(open[rng.randi_range(0, open.size() - 1)])
		else:
			duel._on_done()
		clicks += 1

	# -- the damage division (§1.4): one point per tick --
	func _tick_damage() -> void:
		var candidates: Array[int] = duel._damage_candidates()
		clicks += 1
		if candidates.is_empty():
			duel._on_done()
			return
		var id: int = candidates[rng.randi_range(0, candidates.size() - 1)]
		if id == MtgGame.DAMAGE_TO_PLAYER:
			duel._on_life_clicked(duel.game.opponent_of(SEAT))
			return
		var inst: CardInstance = duel.game.find_instance(id)
		if inst == null:
			duel._on_done()
		else:
			duel._on_card_clicked(inst)

	# -- a cast HELD OPEN for its mana (Mode.PAYING, 2026-09-03) --
	#
	# The 1997 flow is click-the-spell-THEN-draw-the-mana (`Duel.hlp`,
	# topic Spells), so the screen holds the cast open and waits. A fuzzer
	# that did not know the mode sat in it until the stall detector fired
	# — which is exactly what `--stall` is for, and what it caught. Two
	# ways out and the seat takes both: tap the next source the planner
	# names, or (one try in five) drop the cast with Cancel.
	func _tick_paying() -> void:
		var game: MtgGame = duel.game
		clicks += 1
		if rng.randf() < 0.2:
			duel._on_cancel()
			return
		var plan := ManaPlanner.plan(game, SEAT,
			duel._pending_card.data.cost if duel._pending_ability_index < 0
				else duel._pending_card.cur_activated_abilities[
					duel._pending_ability_index].cost,
			0)
		for step in plan:
			var source: CardInstance = step[0]
			if source == null or source.tapped:
				continue          # mana already floating
			if source.cur_mana_abilities.size() == 1 \
					and source.cur_activated_abilities.is_empty():
				duel._on_card_clicked(source)
			else:
				duel._open_ability_menu(source, true)
				duel._ability_menu.hide()
				duel._on_ability_chosen(int(step[1]))
			return
		duel._on_cancel()          # nothing left to tap: give it up

	# -- ordinary priority: dialogs first, then a land, a spell, an ability, or pass --
	func _tick_normal() -> void:
		var game: MtgGame = duel.game
		if duel._mode_overlay != null:
			clicks += 1
			var modes: int = duel._pending_card.data.modes.size() if duel._pending_card != null else 0
			if modes > 0 and rng.randf() < 0.85:
				duel._on_mode_chosen(rng.randi_range(0, modes - 1))
			else:
				duel._on_mode_canceled()
			return
		if duel._search_dialog != null:
			clicks += 1
			var items: int = duel._search_list.item_count
			duel._search_list.deselect_all()
			if items > 0 and rng.randf() < 0.85:
				duel._search_list.select(rng.randi_range(0, items - 1))
			duel._on_search_confirmed()
			return
		if duel._x_dialog != null:
			clicks += 1
			var spin: SpinBox = duel._x_spin
			var steps := int((spin.max_value - spin.min_value) / maxf(spin.step, 1.0))
			spin.value = spin.min_value + rng.randi_range(0, maxi(steps, 0)) * maxf(spin.step, 1.0)
			if rng.randf() < 0.9:
				duel._on_x_confirmed()
			else:
				duel._on_x_canceled()
			return
		if duel.graveyard_is_open():
			clicks += 1
			duel._close_graveyard()
			return
		if duel._ability_menu != null and duel._ability_menu.visible:
			clicks += 1
			duel._ability_menu.hide()
			var inst: CardInstance = game.find_instance(duel._ability_menu.get_meta("instance_id", -1))
			if inst != null and not inst.cur_activated_abilities.is_empty():
				duel._on_ability_chosen(inst.cur_mana_abilities.size()
					+ rng.randi_range(0, inst.cur_activated_abilities.size() - 1))
			return
		if game.awaiting_attackers or game.awaiting_blockers or game.awaiting_discard \
				or game.awaiting_damage_assignment or game.priority_player != SEAT:
			return   # not this seat's moment
		var signature := "%d/%d/%d/%d/%d" % [game.turn_number, game.current_step(),
			game.stack.size(), game.players[SEAT].hand.size(),
			game.players[SEAT].battlefield.size()]
		if signature != _window_signature:
			_window_signature = signature
			_tries = 0
		_tries += 1
		clicks += 1
		if _tries > TRIES_PER_WINDOW:
			duel._on_pass()
			return
		var hand: Array = game.players[SEAT].hand
		var own_main := game.active_player == SEAT and Mtg.is_main_step(game.current_step()) \
			and game.stack.is_empty()
		# A land, first thing on our own main phase.
		if own_main:
			for inst in hand:
				if inst.is_land() and rng.randf() < 0.9:
					duel._on_card_clicked(inst)
					return
		var options: Array = []
		for inst in hand:
			if inst.is_land():
				continue
			if not own_main and not inst.is_type(Mtg.CardType.INSTANT):
				continue
			# `can_afford_cost` plans the lands the cast will auto-tap;
			# `can_afford` reads the pool alone and is false with lands
			# untapped. One try in ten is an unaffordable card on purpose,
			# for the refusal path.
			if game.can_afford_cost(SEAT, inst.data.cost) or rng.randf() < 0.1:
				options.append(inst)
		for inst in game.players[SEAT].battlefield:
			if not inst.cur_activated_abilities.is_empty() and rng.randf() < 0.5:
				options.append(inst)
		if options.is_empty() or rng.randf() < 0.2:
			duel._on_pass()
			return
		var pick: CardInstance = options[rng.randi_range(0, options.size() - 1)]
		if pick.zone == Mtg.Zone.HAND:
			# THE HUMAN SEAT TAPS ITS OWN LANDS (docs/duel-todo.md §9.8 —
			# the original's auto-cast is a deliberate non-build): the
			# cast pays from the pool alone, so the lands are clicked
			# first, then the card.
			_float_mana_for(pick.data.cost, pick.data.cost.has_x)
			duel._on_card_clicked(pick)
		else:
			var abilities: Array = pick.cur_activated_abilities
			var index := rng.randi_range(0, abilities.size() - 1)
			_float_mana_for(abilities[index].cost, abilities[index].cost.has_x)
			# What the click on a permanent with a menu does: open
			# `@MENU_SMALLCARD`'s ability list, then a line is chosen.
			duel._open_ability_menu(pick)
			duel._ability_menu.hide()
			duel._on_ability_chosen(pick.cur_mana_abilities.size() + index)
		if verbose:
			print("    > click %s (%s) -> mode %d, bar: %s" % [pick.data.card_name,
				"hand" if pick.zone == Mtg.Zone.HAND else "table", duel.mode,
				duel._prompt_label.text])

	## Tap the lands that cover [param cost], each by the click its widget
	## would take: a lone mana ability taps on the click itself, a land
	## with a choice goes through the ability menu. The plan is the
	## engine's own (read, not run — the taps below are the clicks). For
	## an {X} cost every untapped source goes, so the X dialog has a
	## budget to offer.
	func _float_mana_for(cost: ManaCost, everything: bool) -> void:
		var game: MtgGame = duel.game
		var plan: Variant = game._payment_plan(SEAT, cost)
		var taps: Array = []
		if plan != null:
			taps = plan
		if everything:
			taps = []
			for inst in game.players[SEAT].battlefield:
				if inst.is_land() and not inst.tapped and not inst.cur_mana_abilities.is_empty():
					taps.append([inst, 0])
		for step in taps:
			var source: CardInstance = step[0]
			var index: int = step[1]
			clicks += 1
			if source.cur_mana_abilities.size() == 1 and source.cur_activated_abilities.is_empty():
				duel._on_card_clicked(source)
			else:
				duel._open_ability_menu(source)
				duel._ability_menu.hide()
				duel._on_ability_chosen(index)
