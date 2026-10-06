extends "res://tools/duel_soak.gd"
## The Tempest block (Pack 9) through the LIVE duel screen: the same
## DuelScreen and the same human-seat fuzzer as the base soak
## (tools/duel_soak.gd), with decks built around the block's new choice
## and payment flows — buyback rows (mana, land-sacrifice), the rows Dream
## Halls and Aluren grant, licids becoming Auras and a licid's "pay to end
## this effect", Volrath's Curse and its "sacrifice a permanent to ignore",
## Reap's target count fixed by its opponent slot, Silver Wyvern's
## retarget, shadow attackers and blockers, Magnetic Web's counters and
## Static Orb's untap question — played whole, by both seats, under either
## rules profile.
##
## The human seat's fuzzer is the base one with three more gestures, each
## through the screen's own handlers and only where a player's hand could
## reach: a payment-row window picks any row the window does not grey (the
## base fuzzer knows only a modal card's modes, so it never reached a
## granted row), a cast held open for its mana taps for the chosen row's
## whole price (a buyback row costs more than the printed cost), and now
## and then a special action is taken from the menu a player would open —
## the licid's or cursed creature's card menu, or the territory menu.
##
## Requires the real local Pack-9-Tempest-Block.zip and the isolated
## shandalar_test profile (tools/runtime.sh `shandalar_test_profile`); writes
## no player settings and no Elo.
##
##   . tools/runtime.sh; shandalar_find_godot; shandalar_find_timeout
##   shandalar_test_profile
##   export SHANDALAR_PACK_9="$PWD/../shandalar-packs/Pack-9-Tempest-Block.zip"
##   xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 1500 "$GODOT" --path . \
##       -s res://tools/pack_9_ui_soak.gd -- --rules modern --count 3 --mode both --pace 0
##   (repeat with --rules fifth)

## Each deck: its name, its lands, nine spells at four copies each.
const SPECS := [
	["Tempest Blue", {"Island": 24}, [
		"Capsize", "Whispers of the Muse", "Volrath's Curse", "Silver Wyvern",
		"Forbid", "Ertai's Meddling", "Thalakos Drifters", "Fighting Drake",
		"Dream Halls"]],
	["Tempest White", {"Plains": 24}, [
		"Soltari Foot Soldier", "Soltari Lancer", "Soltari Monk", "Soltari Champion",
		"Calming Licid", "Quickening Licid", "Anoint", "Pegasus Stampede",
		"Reaping the Rewards"]],
	["Tempest Black", {"Swamp": 24}, [
		"Dauthi Slayer", "Dauthi Horror", "Dauthi Mercenary", "Dauthi Embrace",
		"Corrupting Licid", "Leeching Licid", "Evincar's Justice", "Corpse Dance",
		"Disturbed Burial"]],
	["Tempest Green", {"Forest": 24}, [
		"Reap", "Nurturing Licid", "Tempting Licid", "Spike Feeder", "Spike Worker",
		"Elvish Fury", "Verdant Touch", "Aluren", "Heartwood Dryad"]],
	["Tempest Red", {"Mountain": 24}, [
		"Magnetic Web", "Static Orb", "Enraging Licid", "Convulsing Licid",
		"Searing Touch", "Fanning the Flames", "Seething Anger", "Mogg Fanatic",
		"Jackal Pup"]],
]


func _configure_decks(config: DuelConfig, _first: String, _second: String) -> void:
	if not OS.has_feature("shandalar_test"):
		push_error("Pack 9 UI soak requires the isolated shandalar_test profile")
		quit(3)
		return
	Settings.set_value("enabled_card_packs", [TempestBlockPack.ID], false)
	root.get_node("CardPacks")._configure_registry()
	CardRegistry.ensure_loaded()
	if not CardRegistry.has_card("Soltari Foot Soldier"):
		push_error("Pack 9 UI soak requires the real local Pack-9-Tempest-Block.zip")
		quit(3)
		return
	config.decks = []
	config.player_names = []
	config.printings = [{}, {}]
	for seat in 2:
		var spec: Array = SPECS[(_index + seat) % SPECS.size()]
		var deck: Array[String] = []
		var lands: Dictionary = spec[1]
		for land in lands:
			for _n in int(lands[land]): deck.append(String(land))
		for name in spec[2]:
			if not CardRegistry.has_card(String(name)):
				push_error("Pack 9 UI soak: no card named %s" % name)
				quit(3)
				return
			for _n in 4: deck.append(String(name))
		config.decks.append(deck)
		config.player_names.append(String(spec[0]))


## The base soak's start of a duel, then the Pack 9 fuzzer in the base
## fuzzer's place — the same seed, so a failure replays.
func _next() -> void:
	if _duel != null and _duel.game != null and _index >= 0 and _index < _plan.size():
		_report_flows()
	super._next()
	if _clicker != null and _index < _plan.size():
		var seed_value: int = _plan[_index]["seed"]
		var verbose_was := _clicker.verbose
		_clicker = TempestClicker.new(_duel, seed_value)
		_clicker.verbose = verbose_was


## The Pack 9 flows the finished duel actually went through, read off its
## game log (both seats), and the fuzzer's own row and special-action
## clicks: the evidence that the soak reached them, not only loaded them.
const FLOW_LINES := {
	"buyback paid": " with buyback", "buyback returned": "'s hand (buyback)",
	"granted row": ["(Dream Halls)", "(Aluren)"],
	"licid became an Aura": " becomes an Aura attached to ",
	"licid effect ended": "'s effect", "Curse ignored": " to ignore ",
	"retargeted": " is redirected to ", "magnet": "magnet counter",
	"Reap cast": " casts Reap",
}

func _report_flows() -> void:
	var game: MtgGame = _duel.game
	var counts := {}
	for line in game.log_lines:
		for key in FLOW_LINES:
			var needles: Array = FLOW_LINES[key] if FLOW_LINES[key] is Array else [FLOW_LINES[key]]
			for needle in needles:
				if String(line).contains(String(needle)):
					if key == "licid effect ended" and not String(line).contains(" to end "):
						continue
					if key == "Reap cast" and not String(line).ends_with(" casts Reap"):
						continue
					counts[key] = int(counts.get(key, 0)) + 1
					break
	var parts := PackedStringArray()
	for key in FLOW_LINES:
		parts.append("%s %d" % [key, int(counts.get(key, 0))])
	var step: Dictionary = _plan[_index]
	var fuzz := ""
	if _clicker is TempestClicker:
		fuzz = "; human seat: %d payment rows chosen, %d special actions taken" % [
			(_clicker as TempestClicker).rows_chosen, (_clicker as TempestClicker).specials_taken]
	print("SOAK PACK 9 FLOWS %s seed %d: %s%s" % ["human" if step["human"] else "demo",
		step["seed"], ", ".join(parts), fuzz])


## [HumanClicker] with the Pack 9 gestures (see the file comment). Every
## decision is still drawn from the seeded RNG.
class TempestClicker extends HumanClicker:
	## How often an ordinary priority window first looks for a special action.
	const SPECIAL_CHANCE := 0.2
	var specials_taken := 0
	var rows_chosen := 0

	func _init(p_duel: DuelScreen, seed_value: int) -> void:
		super(p_duel, seed_value)

	func _tick_normal() -> void:
		var game: MtgGame = duel.game
		# THE PAYMENT-ROW WINDOW: every row the window lists and does not
		# grey — the card's modes and printed rows, buyback, and the rows a
		# permanent grants (Dream Halls, Aluren) — exactly the buttons a
		# player could press; one try in seven is Cancel.
		if duel._mode_overlay != null and duel._pending_card != null:
			var inst: CardInstance = duel._pending_card
			var payer: int = duel._pending_pid
			var open: Array[int] = []
			var rows := game.payment_rows(payer, inst)
			for i in rows.size():
				var why := game.payment_row_refusal(payer, inst, i)
				if why == "" or MtgGame.is_unpaid_refusal(why):
					open.append(i)
			clicks += 1
			if open.is_empty() or rng.randf() < 0.15:
				duel._on_mode_canceled()
			else:
				rows_chosen += 1
				duel._on_mode_chosen(open[rng.randi_range(0, open.size() - 1)])
			return
		var menu_open: bool = duel._ability_menu != null and duel._ability_menu.visible
		if not menu_open and game.priority_player == SEAT and game.awaiting_choice == null \
				and duel._search_dialog == null and duel._x_dialog == null \
				and not duel.graveyard_is_open() \
				and not (game.awaiting_attackers or game.awaiting_blockers \
					or game.awaiting_discard or game.awaiting_damage_assignment) \
				and rng.randf() < SPECIAL_CHANCE and _take_special():
			return
		super._tick_normal()

	## A licid's end or Volrath's Curse's ignore, from the menu a player
	## would open for it: the card's own mini-menu (the licid; the Curse or
	## the creature it curses) or the territory menu that lists them all.
	## Only an item the menu does not grey. True when one was taken.
	func _take_special() -> bool:
		var rows: Array = []
		for row: Dictionary in duel._special_actions(SEAT):
			if DuelScreen.ENGINE_SPECIAL_KINDS.has(String(row.get("kind", ""))) \
					and duel._special_action_refusal(SEAT, row) == "":
				rows.append(row)
		if rows.is_empty():
			return false
		var row: Dictionary = rows[rng.randi_range(0, rows.size() - 1)]
		clicks += 1
		var card: Variant = row.get("card")
		if card is CardInstance and rng.randf() < 0.6:
			var on: CardInstance = card
			if String(row["kind"]) == "ignore_effect" and rng.randf() < 0.5:
				var host: CardInstance = duel.game.find_instance(on.attached_to)
				if host != null:
					on = host
			duel._open_card_menu(on, Vector2(400, 300))
			duel._card_menu.hide()
			var at := _find_row(duel._card_specials, row)
			if at < 0:
				return false
			duel._on_card_menu_chosen(DuelScreen.CARD_MENU_SPECIAL_BASE + at)
		else:
			duel._open_territory_menu(SEAT, Vector2(300, 500))
			if duel._territory_menu == null:
				return false
			duel._territory_menu.hide()
			var at := _find_row(duel._territory_specials, row)
			if at < 0:
				return false
			duel._on_territory_menu_chosen(DuelScreen.SPECIAL_BASE + at)
		specials_taken += 1
		if verbose:
			print("    > special action: %s (%s)" % [String(row.get("label", "")), duel._prompt_label.text])
		return true

	static func _find_row(entries: Array, row: Dictionary) -> int:
		for i in entries.size():
			var entry: Dictionary = entries[i]
			if String(entry.get("kind", "")) == String(row.get("kind", "")) \
					and int(entry.get("id", -1)) == int(row.get("id", -2)):
				return i
		return -1

	## A cast held open for its mana: tap toward the WHOLE price of the row
	## chosen — the buyback, a granted row's own mana, the surcharges — as
	## the screen itself prices it ([method DuelScreen._pending_is_reachable]),
	## not the printed cost alone. Abilities keep the base gesture.
	func _tick_paying() -> void:
		var game: MtgGame = duel.game
		if duel._pending_card == null or duel._pending_ability_index >= 0:
			super._tick_paying()
			return
		clicks += 1
		if rng.randf() < 0.2:
			duel._on_cancel()
			return
		var targets: Array = duel._flatten_pending_targets()
		var payment: Dictionary = game.spell_payment(duel._pending_pid, duel._pending_card.data,
			duel._pending_x, maxi(targets.size(), 1), duel._pending_card, duel._pending_mode, targets)
		var plan := ManaPlanner.plan(game, SEAT, payment["cost"], int(payment["extra"]),
			payment["usage"])
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
