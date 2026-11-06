extends GameTest
## PACK 10 IN THE REFEREE'S OPTIONS (DeckLab/referee.gd `options_for`) — what
## a program at the pipe, the MCP door and the decision menus read: the
## Urza block's new actions and questions arrive through the SAME keys as
## every older one, usable only.
##
##  * cycling is a hand card's activated ability in `prepare.abilities`
##    (with its cost), offered to its owner while it can be paid;
##  * a land Yawgmoth's Will lets the seat play from its graveyard is one of
##    `play.lands`;
##  * echo's "pay or sacrifice" and Storage Matrix's kind are `choice`
##    questions of the seat they are for; the other seat waits;
##  * Damping Engine's ignore is a `special` entry of the seat it binds.

const REFEREE := "res://DeckLab/referee.gd"

var referee: SgPracticeMatch
var Referee: Script


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()
	Referee = load(REFEREE)
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	referee = null
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _options(seat := 0) -> Dictionary:
	return Referee.options_for(referee.view(seat), seat)


func _until_asked() -> PlayerChoice:
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 800:
		_advance_once()
		guard += 1
	return g.awaiting_choice


# ---------------------------------------------------------------- cycling --

func test_cycling_is_a_hand_ability_the_program_may_prepare() -> void:
	var clear := give_hand(0, "Clear")
	var listed := func() -> Array:
		return (_options().get("prepare", {}).get("abilities", []) as Array).filter(
			func(entry: Dictionary) -> bool: return entry.card == referee._handle(0, clear))
	assert_eq(listed.call(), [], "no mana in reach: not offered")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var entries: Array = listed.call()
	assert_eq(entries.size(), 1, "two lands to tap: offered")
	if entries.is_empty():
		return
	assert_eq(String(entries[0].name), "Clear")
	assert_string_contains(String(entries[0].label), "Cycling {2}")
	assert_eq(String(entries[0].cost), "{2}")
	assert_eq(_options(1).get("waiting"), true, "the other seat waits")
	assert_ok(referee.act(0, {"op": "autoprepare", "card": referee._handle(0, clear), "kind": "ability",
		"index": int(entries[0].index), "mode": 0, "excluded": [], "count": 1}))
	assert_ok(referee.act(0, {"op": "submit", "targets": []}))
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD, "cycled through the program's door")


# ---------------------------------------------------- Yawgmoth's Will --

func test_a_graveyard_land_under_yawgmoths_will_is_one_of_the_lands_to_play() -> void:
	var forest := give_hand(0, "Forest")
	g.card_to_graveyard_from_anywhere(forest)
	var handle := referee._handle(0, forest)
	var names := func() -> Array:
		return (_options().get("play", {}).get("lands", []) as Array).map(
			func(entry: Dictionary) -> String: return String(entry.card))
	assert_false((names.call() as Array).has(handle), "control: no permission")
	var will := give_hand(0, "Yawgmoth's Will")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, will))
	resolve_stack()
	assert_true((names.call() as Array).has(handle), "the Will's graveyard land")
	assert_ok(referee.act(0, {"op": "play", "card": handle}))
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------- questions --

func test_echos_question_is_the_choice_of_its_controller() -> void:
	put_battlefield(1, "Goblin Patrol")
	put_battlefield(1, "Mountain")
	assert_not_null(_until_asked())
	var theirs := _options(1)
	assert_eq(String(theirs.mode), "choice")
	assert_eq(theirs.get("choice", {}).get("options"), ["Yes", "No"])
	assert_string_contains(String(theirs.choice.prompt), "echo")
	assert_false(theirs.has("cancel"), "a trigger's question is answered, not withdrawn")
	assert_eq(_options(0).get("waiting"), true)


func test_storage_matrixs_kind_is_the_choice_of_the_untapping_seat() -> void:
	put_battlefield(1, "Storage Matrix")
	var forest := put_battlefield(0, "Forest")
	forest.tapped = true
	# Seat 0's next untap step: play through seat 1's turn.
	var guard := 0
	while not (g.awaiting_choice != null and g.awaiting_choice.pid == 0) and guard < 1600:
		_advance_once()
		guard += 1
	var mine := _options(0)
	assert_eq(String(mine.mode), "choice")
	assert_eq(mine.get("choice", {}).get("options"), ["Artifact", "Creature", "Land"])
	assert_eq(_options(1).get("waiting"), true)


func test_damping_engines_ignore_is_a_special_entry_of_the_bound_seat() -> void:
	put_battlefield(1, "Damping Engine")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	g.recalculate()
	var labels: Array = (_options().get("special", {}).get("specials", []) as Array).map(
		func(entry: Dictionary) -> String: return String(entry.label))
	assert_true(labels.has("Sacrifice a permanent: ignore Damping Engine this turn"), str(labels))


func test_the_permitted_library_top_is_a_cast_of_the_program() -> void:
	# The library top a zone permission names (Temporal Aperture) is a card of
	# the seat's view since protocol 31 (`library_top`), so a program at the
	# pipe or the MCP door sees it among its casts — the free row only.
	var bears := give_hand(0, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(bears)
	g.grant_zone_play(0, {"zone": Mtg.Zone.LIBRARY, "card": bears, "lands": true, "spells": true, "free": true})
	var casts: Array = (_options().get("prepare", {}).get("casts", []) as Array).filter(
		func(entry: Dictionary) -> bool: return entry.card == referee._handle(0, bears))
	assert_eq(casts.size(), 1)
	if casts.size() == 1:
		assert_eq(casts[0].get("usable_modes"), [1], "the free row only")
