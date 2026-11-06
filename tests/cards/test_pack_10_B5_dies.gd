extends GameTest
## Pack 10 (the Urza block), batch B5: the "when this creature dies"
## triggers of cards/sets/usg/_triggers.gd and cards/sets/uds/_triggers.gd
## — heard by the departing card (CR 603.10a), "you" the seat that
## controlled it as it died, "you may exile it. If you do" acting only on
## the card that died this time (CR 400.7) — and the sacrifice-to-draw and
## reanimation activations of the same cards.

class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


## Put [param names] on top of [param pid]'s library, the LAST name on top.
func stack_library(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for n in names:
		var card := _make_instance(pid, n)
		card.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(card)
		out.append(card)
	return out

func _kill(i: CardInstance) -> void:
	g.destroy(i)
	resolve_stack()


# --------------------------------------------------------------------- Cathodion --

func test_cathodion_adds_three_colorless_to_its_last_controller() -> void:
	var cathodion := put_battlefield(1, "Cathodion")
	g.change_control(cathodion, 0)
	_kill(cathodion)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 3, "the controller at death")
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.C), 0)


# ---------------------------------------------------------------- Academy Rector --

func test_academy_rector_exiles_itself_and_fetches_an_enchantment() -> void:
	var lib := stack_library(0, ["Crusade", "Forest"])
	var rector := put_battlefield(0, "Academy Rector")
	me.prefer = ["Crusade"]
	_kill(rector)
	assert_eq(rector.zone, Mtg.Zone.EXILE)
	assert_eq(lib[0].zone, Mtg.Zone.BATTLEFIELD, "Crusade entered")
	assert_eq(lib[0].controller_id, 0)

func test_academy_rector_may_decline_and_stays_in_the_graveyard() -> void:
	var lib := stack_library(0, ["Crusade"])
	var rector := put_battlefield(0, "Academy Rector")
	me.yes = 0
	_kill(rector)
	assert_eq(rector.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lib[0].zone, Mtg.Zone.LIBRARY)

func test_academy_rector_does_nothing_once_its_card_has_left_the_graveyard() -> void:
	var lib := stack_library(0, ["Crusade"])
	var rector := put_battlefield(0, "Academy Rector")
	g.destroy(rector)
	assert_eq(g.stack.size(), 1)
	g.exile_from_graveyard(rector)
	resolve_stack()
	assert_eq(lib[0].zone, Mtg.Zone.LIBRARY, "no exile, so no search ('if you do')")

func test_academy_rector_puts_an_aura_onto_a_creature() -> void:
	var lib := stack_library(0, ["Holy Strength"])
	var bear := put_battlefield(0, "Grizzly Bears")
	var rector := put_battlefield(0, "Academy Rector")
	_kill(rector)
	assert_eq(lib[0].zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(lib[0].attached_to, bear.id)

func test_academy_rector_cannot_find_an_aura_with_nothing_to_enchant() -> void:
	var lib := stack_library(0, ["Holy Strength"])
	var rector := put_battlefield(0, "Academy Rector")
	_kill(rector)
	assert_eq(rector.zone, Mtg.Zone.EXILE)
	assert_eq(lib[0].zone, Mtg.Zone.LIBRARY, "CR 303.4f: it stays in the library")


# ----------------------------------------------------------------- False Prophet --

func test_false_prophet_exiles_every_creature() -> void:
	var prophet := put_battlefield(0, "False Prophet")
	var mine := put_battlefield(0, "Grizzly Bears")
	var troll := put_battlefield(1, "Uthden Troll")
	troll.regeneration_shields = 1   # setup: exile ignores it
	var ring := put_battlefield(1, "Sol Ring")
	_kill(prophet)
	assert_eq(prophet.zone, Mtg.Zone.GRAVEYARD, "it had died already")
	assert_eq(mine.zone, Mtg.Zone.EXILE)
	assert_eq(troll.zone, Mtg.Zone.EXILE)
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD, "creatures only")


# ---------------------------------------------------------------- Reliquary Monk --

func test_reliquary_monk_destroys_an_artifact_or_enchantment() -> void:
	var monk := put_battlefield(0, "Reliquary Monk")
	var ring := put_battlefield(1, "Sol Ring")
	_kill(monk)
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)

func test_reliquary_monk_has_no_trigger_without_a_target() -> void:
	var monk := put_battlefield(0, "Reliquary Monk")
	g.destroy(monk)
	assert_true(g.stack.is_empty(), "CR 603.3d")


# -------------------------------------------------------------------- Aura Thief --

func test_aura_thief_takes_every_enchantment_and_leaves_auras_in_place() -> void:
	var thief := put_battlefield(0, "Aura Thief")
	var moon := put_battlefield(1, "Bad Moon")
	var bear := put_battlefield(1, "Grizzly Bears")
	var strength := give_hand(1, "Holy Strength")
	g.attach_aura_from_anywhere(strength, bear, 1)
	assert_eq(strength.attached_to, bear.id)
	_kill(thief)
	assert_eq(moon.controller_id, 0)
	assert_eq(strength.controller_id, 0)
	assert_eq(strength.attached_to, bear.id, "you don't get to move Auras")
	assert_eq(bear.controller_id, 1)


# -------------------------------------------------------------------- Kingfisher --

func test_kingfisher_draws_a_card_when_it_dies() -> void:
	var bird := put_battlefield(0, "Kingfisher")
	var hand := g.players[0].hand.size()
	_kill(bird)
	assert_eq(g.players[0].hand.size(), hand + 1)


# ------------------------------------------------------------------ Body Snatcher --

func test_body_snatcher_exiles_itself_and_raises_another_creature_card() -> void:
	var giant := give_hand(0, "Hill Giant")
	g.discard_cards(0, [giant])
	var bear := give_hand(0, "Grizzly Bears")
	var snatcher := put_battlefield(0, "Body Snatcher")
	resolve_stack()   # its enters trigger: it discards the Bears to stay
	assert_eq(snatcher.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	_kill(snatcher)
	assert_eq(snatcher.zone, Mtg.Zone.EXILE)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the biggest other body is the hint")
	assert_eq(giant.controller_id, 0)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_body_snatcher_naming_itself_finds_nothing() -> void:
	var snatcher := put_battlefield(0, "Body Snatcher")
	give_hand(0, "Grizzly Bears")
	me.prefer = ["Grizzly Bears"]
	resolve_stack()
	assert_eq(snatcher.zone, Mtg.Zone.BATTLEFIELD)
	me.prefer = ["Body Snatcher"]
	_kill(snatcher)
	assert_eq(snatcher.zone, Mtg.Zone.EXILE, "exiled first; the return finds nothing")


# --------------------------------------------------------------- Disease Carriers --

func test_disease_carriers_shrinks_target_creature() -> void:
	var carriers := put_battlefield(0, "Disease Carriers")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	_kill(carriers)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the opponent's first: -2/-2 kills a 2/2")
	assert_eq(giant.cur_power, 3)


# -------------------------------------------------------------------- Plague Dogs --

func test_plague_dogs_shrinks_all_creatures_and_can_be_sacrificed_to_draw() -> void:
	var dogs := put_battlefield(0, "Plague Dogs")
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, dogs, 0))
	assert_eq(dogs.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.cur_power, 2)
	assert_eq(giant.cur_toughness, 2)


# ----------------------------------------------------- Goblin Gardener, Goblin Masons --

func test_goblin_gardener_destroys_target_land() -> void:
	var gardener := put_battlefield(0, "Goblin Gardener")
	var theirs := put_battlefield(1, "Forest")
	var mine := put_battlefield(0, "Mountain")
	_kill(gardener)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)

func test_goblin_masons_destroys_a_wall_and_nothing_else() -> void:
	var masons := put_battlefield(0, "Goblin Masons")
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	_kill(masons)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	var second := put_battlefield(0, "Goblin Masons")
	g.destroy(second)
	assert_true(g.stack.is_empty(), "no Wall, no trigger")


# --------------------------------------------------------------------- Gamekeeper --

func test_gamekeeper_reveals_until_a_creature_and_buries_the_rest() -> void:
	var lib := stack_library(0, ["Hill Giant", "Island", "Lightning Bolt"])
	var keeper := put_battlefield(0, "Gamekeeper")
	_kill(keeper)
	assert_eq(keeper.zone, Mtg.Zone.EXILE)
	assert_eq(lib[0].zone, Mtg.Zone.BATTLEFIELD, "the Giant")
	assert_eq(lib[1].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lib[2].zone, Mtg.Zone.GRAVEYARD)

func test_gamekeeper_declined_stays_in_the_graveyard() -> void:
	var lib := stack_library(0, ["Hill Giant"])
	var keeper := put_battlefield(0, "Gamekeeper")
	me.yes = 0
	_kill(keeper)
	assert_eq(keeper.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lib[0].zone, Mtg.Zone.LIBRARY)


# ----------------------------------------------------------------- Marker Beetles --

func test_marker_beetles_pumps_your_creature() -> void:
	var beetles := put_battlefield(0, "Marker Beetles")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	_kill(beetles)
	assert_eq(bear.cur_power, 3)
	assert_eq(bear.cur_toughness, 3)


# ----------------------------------------------------------------- Yavimaya Elder --

func test_yavimaya_elder_finds_two_basic_lands_revealed() -> void:
	g.players[0].library.clear()
	var lib := stack_library(0, ["Forest", "Lightning Bolt", "Island", "Swamp"])
	var elder := put_battlefield(0, "Yavimaya Elder")
	var shown: Array = []
	g.information_revealed.connect(func(viewer: int, _t: String, cards: Array) -> void:
		shown.append([viewer, cards]))
	_kill(elder)
	var found := lib.filter(func(c: CardInstance) -> bool: return c.zone == Mtg.Zone.HAND)
	assert_eq(found.size(), 2)
	for c in found: assert_true(c.data.is_land())
	assert_eq(lib[1].zone, Mtg.Zone.LIBRARY, "not a basic land")
	assert_eq(shown.size(), 2)
	assert_eq(int(shown[0][0]), -1, "revealed to everyone")

func test_yavimaya_elder_can_be_sacrificed_to_draw() -> void:
	var elder := put_battlefield(0, "Yavimaya Elder")
	me.yes = 0
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, elder, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "the draw; the declined search added nothing")


# --------------------------------------------------------------------- Junk Diver --

func test_junk_diver_returns_another_artifact_card() -> void:
	var ring := _make_instance(0, "Sol Ring")
	ring.zone = Mtg.Zone.HAND
	g.players[0].hand.append(ring)
	g.discard_cards(0, [ring])
	var diver := put_battlefield(0, "Junk Diver")
	_kill(diver)
	assert_eq(ring.zone, Mtg.Zone.HAND)
	assert_eq(diver.zone, Mtg.Zone.GRAVEYARD)

func test_junk_diver_cannot_return_itself() -> void:
	var diver := put_battlefield(0, "Junk Diver")
	g.destroy(diver)
	assert_true(g.stack.is_empty(), "another target: none")


# ---------------------------------------------------------- Apprentice Necromancer --

func test_apprentice_necromancer_raises_a_hasty_creature_sacrificed_at_end_step() -> void:
	var giant := give_hand(0, "Hill Giant")
	g.discard_cards(0, [giant])
	var necro := put_battlefield(0, "Apprentice Necromancer")
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.activate_ability(0, necro, 0, [TargetRef.card(giant)]))
	assert_eq(necro.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(giant.has_keyword(Mtg.Keyword.HASTE))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "sacrificed at the beginning of the next end step")

func test_apprentice_necromancer_cannot_target_itself() -> void:
	var necro := put_battlefield(0, "Apprentice Necromancer")
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_refused(g.activate_ability(0, necro, 0, [TargetRef.card(necro)]))


func test_body_snatcher_fizzles_whole_when_its_target_leaves() -> void:
	var giant := give_hand(0, "Hill Giant")
	g.discard_cards(0, [giant])
	give_hand(0, "Grizzly Bears")
	var snatcher := put_battlefield(0, "Body Snatcher")
	resolve_stack()
	me.prefer = ["Hill Giant"]
	g.destroy(snatcher)
	assert_eq(g.stack.size(), 1)
	g.exile_from_graveyard(giant)
	resolve_stack()
	assert_eq(snatcher.zone, Mtg.Zone.GRAVEYARD, "an illegal target: nothing happens, not even the exile (CR 608.2b)")
