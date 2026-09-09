extends GameTest
## LIFETAP AND A CONVERTED FOREST (2026-09-09). The owner, from a
## playtest:
##
## *"If i cast phantasmal terrain on a land of opponent to convert to
## forest for example. And then cast lifetap. I dont get life when
## opponent taps this 'converted forest'."*
##
## Lifetap pays on the LIVE characteristic — *"Whenever a Forest an
## opponent controls becomes tapped, you gain 1 life"* reads the land as
## it is when the tap happens, not as it was printed (CR 613.1d puts a
## subtype change in layer 4, and CR 603.2 tests the trigger against the
## game state at the moment of the event). A Plains wearing Phantasmal
## Terrain that named Forest IS a Forest, and every way of tapping it
## pays.
##
## The type is chosen the way the owner chooses it — through the held
## question the aura's arrival trigger puts to the caster's seat, not by
## writing the answer into the aura's memory behind the engine's back.


const PLAINS := 0
const ISLAND := 1
const SWAMP := 2
const MOUNTAIN := 3
const FOREST := 4


## Seat [param pid] answers its own held questions itself, the way the
## table does — the aura's "choose a basic land type" is the owner's.
func _human_seat(pid: int) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


## CAST a Phantasmal Terrain from [param pid]'s hand at [param host] and
## name [param type_index] — through the question the engine holds the
## resolution open on, which is the road the owner's click takes. Must be
## called in [param pid]'s own main phase (it is a sorcery-speed spell).
## Returns the aura.
func _terrain(pid: int, host: CardInstance, type_index: int) -> CardInstance:
	_human_seat(pid)
	var aura := give_hand(pid, "Phantasmal Terrain")
	add_mana(pid, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	_answer_the_type(type_index)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "the Aura resolved")
	return aura


## Let the spell resolve, answering the one question it asks.
func _answer_the_type(type_index: int) -> void:
	var guard := 0
	while (not g.stack.is_empty() or g.awaiting_choice != null) and guard < 40:
		if g.awaiting_choice != null:
			assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION,
				"the aura asks for a basic land type")
			assert_ok(g.answer_choice(type_index))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 40, "the Aura settled")


## Hand the turn over until [param pid] is the active player in main 1 —
## always a LATER turn than the one we are in, so a land that was tapped
## has had its controller's untap step.
func _to_main_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while (g.turn_number == turn or g.active_player != pid \
			or g.current_step() != Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		if g.awaiting_choice != null:
			assert_ok(g.answer_choice(g.awaiting_choice.hint))
		elif g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		elif g.awaiting_discard:
			assert_ok(g.discard_to_hand_size(g.active_player, []))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 400, "reached seat %d's main phase" % pid)


func _settle() -> void:
	var guard := 0
	while (not g.stack.is_empty() or g.awaiting_choice != null) and guard < 40:
		if g.awaiting_choice != null:
			assert_ok(g.answer_choice(g.awaiting_choice.hint))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ============================================== the owner's board, exactly --

func test_the_owners_case_a_converted_forest_pays() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	_terrain(0, theirs, FOREST)
	assert_true(theirs.has_subtype("forest"), "the Plains IS a Forest now")
	assert_false(theirs.has_subtype("plains"), "and is nothing else (CR 305.7)")
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 21,
		"the opponent tapped a Forest we made — Lifetap pays 1")


func test_the_converted_land_taps_for_the_new_colour() -> void:
	# The land the owner watched: it really is a Forest, mana and all.
	var theirs := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	_terrain(0, theirs, FOREST)
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 1,
		"a converted Forest makes {G}, not {W}")


func test_a_real_forest_still_pays() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Forest")
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 21, "the printed Forest pays as it always did")


func test_our_own_converted_forest_does_not_pay() -> void:
	put_battlefield(0, "Lifetap")
	var ours := put_battlefield(0, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	_terrain(0, ours, FOREST)
	assert_ok(g.tap_for_mana(0, ours))
	_settle()
	assert_eq(g.players[0].life, 20, "it says an OPPONENT's Forest")


func test_a_terrain_naming_something_else_pays_nothing() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	_terrain(0, theirs, SWAMP)
	assert_false(theirs.has_subtype("forest"),
		"the aura replaced the printed Forest with a Swamp")
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 20, "a Swamp is not a Forest")


func test_the_aura_leaving_stops_the_payments() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	var aura := _terrain(0, theirs, FOREST)
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 21, "paid while the aura stood")
	g.destroy(aura)
	g.recalculate()
	assert_true(theirs.has_subtype("plains"), "the land is a Plains again")
	_to_main_of(1)
	assert_false(theirs.tapped, "it untapped in its controller's untap step")
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 21, "and pays nothing once the aura is gone")


# ============================================ every other way of tapping it --

func test_an_icy_manipulator_tapping_it_pays() -> void:
	put_battlefield(0, "Lifetap")
	var icy := put_battlefield(0, "Icy Manipulator")
	var theirs := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	_terrain(0, theirs, FOREST)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(theirs)]))
	_settle()
	assert_true(theirs.tapped, "the Icy tapped it")
	assert_eq(g.players[0].life, 21, "any tap counts, not only a tap for mana")


func test_an_animated_converted_land_pays_when_it_attacks() -> void:
	# Living Lands makes every land a 1/1 creature; a converted Forest that
	# attacks TAPS (CR 508.1f), and that is "becomes tapped" too. The life
	# is read at the DECLARATION, before the 1/1 gets through for its
	# point — otherwise the damage and the gain cancel and the assertion
	# passes on a board where nothing triggered at all.
	put_battlefield(1, "Lifetap")
	var mine := put_battlefield(0, "Plains")
	_to_main_of(1)
	_terrain(1, mine, FOREST)
	put_battlefield(0, "Living Lands")
	_to_main_of(0)
	g.recalculate()
	assert_true(mine.is_creature(), "Living Lands animated it")
	assert_true(mine.has_subtype("forest"), "and it is still the aura's Forest")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.active_player, 0, "our turn to swing")
	assert_ok(g.declare_attackers(0, [mine.id]))
	assert_true(mine.tapped, "attacking tapped it (CR 508.1f)")
	_settle()
	assert_eq(g.players[1].life, 21, "their Lifetap paid for our attack")


func test_every_tap_pays_again_next_turn() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	_terrain(0, theirs, FOREST)
	for i in 2:
		_to_main_of(1)
		assert_ok(g.tap_for_mana(1, theirs))
		_settle()
	assert_eq(g.players[0].life, 22, "one life per tap, two turns running")


# ============================== the other land-type changers in the pool --

func test_gaeas_liege_makes_a_forest_lifetap_can_read() -> void:
	put_battlefield(0, "Lifetap")
	# The Liege is a */* equal to the Forests we control: with none it is
	# a 0/0 and dies to state-based actions before it can be tapped.
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var liege := put_battlefield(0, "Gaea's Liege")
	var theirs := put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, liege, 0, [TargetRef.card(theirs)]))
	_settle()
	assert_true(theirs.has_subtype("forest"), "the Liege made it a Forest")
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 21, "and Lifetap reads the Liege's Forest")


func test_evil_presence_makes_a_swamp_lifetap_ignores() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Forest")
	var aura := _make_instance(0, "Evil Presence")
	g.attach_aura_from_anywhere(aura, theirs, 0)
	_settle()
	assert_false(theirs.has_subtype("forest"), "a Swamp, and only a Swamp")
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 20, "nothing to pay for")


func test_blood_moon_turns_a_nonbasic_forest_off() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Taiga")   # Forest Mountain, nonbasic
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 21, "a Taiga is a Forest")
	put_battlefield(0, "Blood Moon")
	g.recalculate()
	assert_false(theirs.has_subtype("forest"), "nonbasic lands are Mountains")
	_to_main_of(1)
	assert_ok(g.tap_for_mana(1, theirs))
	_settle()
	assert_eq(g.players[0].life, 21, "and a Mountain pays nothing")


# ================================= THE WINDOW THE OWNER'S TAP FELL INTO --
#
# "As this Aura enters, choose a basic land type" is a REPLACEMENT effect
# (CR 614.1c): applied AS the Aura enters, using no stack. Modelled as an
# ENTERS_BATTLEFIELD trigger it became a stack object instead, and between
# the Aura arriving and that object resolving BOTH PLAYERS HELD PRIORITY
# over a land that was still its printed self. The opponent tapping it
# then tapped a Plains — for {W}, and for no life.

func test_the_type_is_named_as_the_aura_enters() -> void:
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	var aura := give_hand(0, "Phantasmal Terrain")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(theirs)]))
	# Stop at the FIRST moment the Aura is on the battlefield — the moment
	# a player could next act — and read the land there.
	var guard := 0
	while aura.zone != Mtg.Zone.BATTLEFIELD and guard < 40:
		if g.awaiting_choice != null:
			assert_ok(g.answer_choice(FOREST))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "the Aura is on the battlefield")
	assert_true(g.stack.is_empty(),
		"and nothing of its own is waiting on the stack (CR 614.1c)")
	assert_true(theirs.has_subtype("forest"),
		"the land is ALREADY the named type — no window in between")
	assert_eq(theirs.cur_mana_abilities.size(), 1, "one intrinsic ability")
	assert_eq(int(theirs.cur_mana_abilities[0].produces[0][0]), Mtg.ManaColor.G,
		"and it makes {G} already, not the {W} it was printed with")


func test_the_opponent_tapping_it_at_that_moment_pays() -> void:
	# The owner's tap, taken at the earliest instant the opponent could
	# take it: a mana ability may be activated whenever a cost could be
	# paid (CR 605.3a), so this is the first tap the board allows.
	put_battlefield(0, "Lifetap")
	var theirs := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	_human_seat(0)
	var aura := give_hand(0, "Phantasmal Terrain")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(theirs)]))
	var guard := 0
	while aura.zone != Mtg.Zone.BATTLEFIELD and guard < 40:
		if g.awaiting_choice != null:
			assert_ok(g.answer_choice(FOREST))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.tap_for_mana(1, theirs))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 1,
		"they tapped a Forest, so they got {G}")
	_settle()
	assert_eq(g.players[0].life, 21, "and Lifetap paid for it")


func test_the_choice_is_not_a_trigger_anybody_can_answer_to() -> void:
	# A replacement effect is not put on the stack, so the opponent never
	# gets a window to respond to the naming itself.
	var terrain := CardRegistry.get_card("Phantasmal Terrain")
	assert_true(terrain.as_enters.is_valid(),
		"the naming is CardData.as_enters (CR 614.1c)")
	for trig in terrain.triggered_abilities:
		assert_ne(trig.event_type, Mtg.EventType.ENTERS_BATTLEFIELD,
			"and not an arrival trigger")
