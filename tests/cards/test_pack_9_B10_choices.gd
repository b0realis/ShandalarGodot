extends GameTest
## Pack 9 (the Tempest block), batch B10: the Stronghold hidden-zone picks
## in cards/sets/sth/_choices.gd — Hermit Druid, Mulch and Ransack.

const CLAIMED := ["Hermit Druid", "Mulch", "Ransack"]

## Says yes to the Ransack question about each card named in [member down].
class Seat extends DecisionAgent:
	var down: Array[String] = []
	var asked := 0
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked += 1
		for name in down:
			if prompt.contains(name): return true
		return false

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

## SETUP: put [param names] on top of [param pid]'s library, the first
## name ending on top. Returns the cards, top first.
func _stack(pid: int, names: Array) -> Array[CardInstance]:
	var made: Array[CardInstance] = []
	for n in range(names.size() - 1, -1, -1):
		var inst := _make_instance(pid, String(names[n]))
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)
		made.push_front(inst)
	return made

func _top_names(pid: int, n: int) -> Array:
	var out: Array = []
	var library := g.players[pid].library
	for k in mini(n, library.size()): out.append(library[library.size() - 1 - k].data.card_name)
	return out


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ---------------------------------------------------------------- Hermit Druid --

func test_hermit_druid_digs_to_a_basic_land() -> void:
	var druid := put_battlefield(0, "Hermit Druid")
	var cards := _stack(0, ["Grizzly Bears", "Badlands", "Hill Giant", "Forest", "Shivan Dragon"])
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, druid, 0, []))
	resolve_stack()
	assert_eq(cards[3].zone, Mtg.Zone.HAND, "the basic land")
	for k in 3: assert_eq(cards[k].zone, Mtg.Zone.GRAVEYARD, cards[k].data.card_name)
	assert_eq(cards[4].zone, Mtg.Zone.LIBRARY, "never revealed")
	assert_eq(_top_names(0, 1), ["Shivan Dragon"])

func test_hermit_druid_with_no_basic_land_mills_everything() -> void:
	var druid := put_battlefield(0, "Hermit Druid")
	g.players[0].library.clear()   # setup: no Forest filler
	var cards := _stack(0, ["Grizzly Bears", "Badlands"])
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, druid, 0, []))
	resolve_stack()
	assert_eq(g.players[0].library.size(), 0)
	assert_eq(cards[0].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD)
	assert_false(g.game_over, "revealing is not drawing")

func test_hermit_druid_on_an_empty_library_does_nothing() -> void:
	var druid := put_battlefield(0, "Hermit Druid")
	g.players[0].library.clear()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, druid, 0, []))
	resolve_stack()
	assert_false(g.game_over)

func test_hermit_druid_taps_so_it_cant_be_sick() -> void:
	var druid := put_battlefield(0, "Hermit Druid", true)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, druid, 0, []))


# ----------------------------------------------------------------------- Mulch --

func test_mulch_lands_to_hand_the_rest_to_the_graveyard() -> void:
	var cards := _stack(0, ["Forest", "Grizzly Bears", "Badlands", "Hill Giant", "Shivan Dragon"])
	advance_to_step(Mtg.Step.MAIN1)
	var mulch := give_hand(0, "Mulch")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, mulch, []))
	resolve_stack()
	assert_eq(cards[0].zone, Mtg.Zone.HAND)
	assert_eq(cards[2].zone, Mtg.Zone.HAND, "a nonbasic land is a land card too")
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cards[3].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cards[4].zone, Mtg.Zone.LIBRARY, "only four")

func test_mulch_with_a_short_library() -> void:
	g.players[0].library.clear()
	var cards := _stack(0, ["Grizzly Bears", "Forest"])
	advance_to_step(Mtg.Step.MAIN1)
	var mulch := give_hand(0, "Mulch")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, mulch, []))
	resolve_stack()
	assert_eq(cards[0].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cards[1].zone, Mtg.Zone.HAND)
	assert_false(g.game_over)


# --------------------------------------------------------------------- Ransack --

func test_ransack_sends_the_chosen_cards_to_the_bottom() -> void:
	var seat := Seat.new()
	seat.down = ["Shivan Dragon", "Hill Giant"]
	g.set_agent(0, seat)
	var cards := _stack(1, ["Shivan Dragon", "Forest", "Hill Giant", "Grizzly Bears", "Gray Ogre", "Serra Angel"])
	advance_to_step(Mtg.Step.MAIN1)
	var size := g.players[1].library.size()
	var ransack := give_hand(0, "Ransack")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, ransack, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(seat.asked, 5, "one question for each of the top five")
	var library := g.players[1].library
	assert_eq(library.size(), size)
	var bottom := [library[0].data.card_name, library[1].data.card_name]
	bottom.sort()
	assert_eq(bottom, ["Hill Giant", "Shivan Dragon"])
	var top := _top_names(1, 3)
	top.sort()
	assert_eq(top, ["Forest", "Gray Ogre", "Grizzly Bears"], "the rest back on top")
	assert_eq(_top_names(1, 4)[3], "Serra Angel", "the sixth card stays where it was")
	assert_eq(cards[5].zone, Mtg.Zone.LIBRARY)

func test_ransack_keeping_everything_only_reorders() -> void:
	var seat := Seat.new()
	g.set_agent(0, seat)
	_stack(0, ["Shivan Dragon", "Forest", "Hill Giant"])
	advance_to_step(Mtg.Step.MAIN1)
	var bottom_before: String = g.players[0].library[0].data.card_name
	var ransack := give_hand(0, "Ransack")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, ransack, [TargetRef.player(0)]))
	resolve_stack()
	var top := _top_names(0, 5)
	top.sort()
	assert_eq(top, ["Forest", "Forest", "Forest", "Hill Giant", "Shivan Dragon"])
	assert_eq(g.players[0].library[0].data.card_name, bottom_before)

func test_ransack_on_a_short_library() -> void:
	g.players[1].library.clear()
	_stack(1, ["Grizzly Bears", "Forest"])
	advance_to_step(Mtg.Step.MAIN1)
	var ransack := give_hand(0, "Ransack")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, ransack, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].library.size(), 2)

func test_ransack_targets_a_player_only() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var ransack := give_hand(0, "Ransack")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_refused(g.cast_spell(0, ransack, [TargetRef.card(bear)]))
