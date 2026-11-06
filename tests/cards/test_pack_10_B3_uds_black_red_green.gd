extends GameTest
## Pack 10 (the Urza block), batch B3: the black, red and green Urza's
## Destiny creatures of cards/sets/uds/_creatures.gd — Phyrexian Monitor,
## Slinking Skirge, Bloodshot Cyclops, Colos Yearling, Hulking Ogre, Ancient
## Silverback, Elvish Lookout, Elvish Piper, Taunting Elf and Yavimaya
## Enchantress. Each test pins the clause that makes the card that card,
## with its refused case; Elvish Piper's question is also held open for a
## human seat.

const CLAIMED := ["Phyrexian Monitor", "Slinking Skirge", "Bloodshot Cyclops", "Colos Yearling",
	"Hulking Ogre", "Ancient Silverback", "Elvish Lookout", "Elvish Piper", "Taunting Elf",
	"Yavimaya Enchantress"]


## FIFO card picks (a null pick declines); an empty queue takes the first
## candidate.
class Scripted extends DecisionAgent:
	var picks: Array = []
	var offered: Array = []

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		offered.append(candidates.duplicate())
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		if want == null:
			return null
		for c in candidates:
			if want is CardInstance and c == want:
				return c
		return null


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card

## P0 attacks with [param attacker]; P1 is to declare blockers.
func _attack(attacker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_eq(c.set_code, "uds", card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Phyrexian Monitor / Ancient Silverback ---------------------------------

## name -> the one mana its regeneration costs.
const REGENERATORS := {"Phyrexian Monitor": Mtg.ManaColor.B, "Ancient Silverback": Mtg.ManaColor.G}

func test_the_regenerators_regenerate_for_one_colored_mana() -> void:
	for card_name in REGENERATORS:
		var body := put_battlefield(0, card_name)
		assert_refused(g.activate_ability(0, body, 0), "mana")
		add_mana(0, int(REGENERATORS[card_name]))
		assert_ok(g.activate_ability(0, body, 0))
		resolve_stack()
		g.destroy(body)
		assert_eq(body.zone, Mtg.Zone.BATTLEFIELD, card_name)
		assert_true(body.tapped, card_name)


# --- Slinking Skirge --------------------------------------------------------

func test_slinking_skirge_sacrifices_itself_to_draw() -> void:
	var skirge := put_battlefield(0, "Slinking Skirge")
	assert_true(skirge.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, skirge, 0), "mana")
	add_mana(0, Mtg.ManaColor.C)
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, skirge, 0))
	assert_eq(skirge.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)


# --- Bloodshot Cyclops ------------------------------------------------------

func test_bloodshot_cyclops_hurls_a_creature_for_its_power() -> void:
	var p0 := seat(0)
	var cyclops := put_battlefield(0, "Bloodshot Cyclops")
	var wurm := put_battlefield(0, "Craw Wurm")
	var giant := put_battlefield(1, "Hill Giant")
	p0.picks = [wurm]
	assert_ok(g.activate_ability(0, cyclops, 0, [TargetRef.player(1)]))
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_true(cyclops.tapped)
	resolve_stack()
	assert_eq(g.players[1].life, 14, "the Wurm's 6")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

## The Cyclops may throw itself; the damage is still the Cyclops's, by
## its last known information (CR 608.2h).
func test_bloodshot_cyclops_may_hurl_itself() -> void:
	var p0 := seat(0)
	var cyclops := put_battlefield(0, "Bloodshot Cyclops")
	var giant := put_battlefield(1, "Hill Giant")
	p0.picks = [cyclops]
	assert_ok(g.activate_ability(0, cyclops, 0, [TargetRef.card(giant)]))
	assert_eq(cyclops.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "4 damage")

func test_bloodshot_cyclops_needs_its_tap() -> void:
	var cyclops := put_battlefield(0, "Bloodshot Cyclops", true)
	put_battlefield(0, "Craw Wurm")
	assert_refused(g.activate_ability(0, cyclops, 0, [TargetRef.player(1)]))


# --- Colos Yearling ---------------------------------------------------------

func test_colos_yearling_walks_mountains_and_pumps_its_power() -> void:
	var yearling := put_battlefield(0, "Colos Yearling")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_eq(yearling.cur_landwalk, ["mountain"])
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, yearling, 0))
	assert_ok(g.activate_ability(0, yearling, 0))
	resolve_stack()
	assert_eq([yearling.cur_power, yearling.cur_toughness], [3, 1])
	put_battlefield(1, "Mountain")
	_attack(yearling)
	assert_refused(g.declare_blockers(1, {bear.id: yearling.id}))
	assert_ok(g.declare_blockers(1, {}))


# --- Hulking Ogre -----------------------------------------------------------

func test_hulking_ogre_cannot_block() -> void:
	var ogre := put_battlefield(1, "Hulking Ogre")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack(bear)
	assert_refused(g.declare_blockers(1, {ogre.id: bear.id}))
	assert_ok(g.declare_blockers(1, {}))

func test_hulking_ogre_can_attack() -> void:
	var ogre := put_battlefield(0, "Hulking Ogre")
	_attack(ogre)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17)


# --- Elvish Lookout ---------------------------------------------------------

func test_elvish_lookout_has_shroud() -> void:
	var lookout := put_battlefield(0, "Elvish Lookout")
	assert_true(lookout.cur_shroud)
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(lookout)]))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(lookout)]))


# --- Elvish Piper -----------------------------------------------------------

func test_elvish_piper_puts_a_creature_card_from_hand_onto_the_battlefield() -> void:
	var p0 := seat(0)
	var piper := put_battlefield(0, "Elvish Piper")
	var dragon := give_hand(0, "Shivan Dragon")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.G)
	p0.picks = [dragon]
	assert_ok(g.activate_ability(0, piper, 0))
	assert_true(piper.tapped)
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dragon.controller_id, 0)
	assert_false(p0.offered[-1].has(bolt), "only creature cards are offered")
	assert_eq(bolt.zone, Mtg.Zone.HAND)

func test_elvish_piper_may_decline() -> void:
	var p0 := seat(0)
	var piper := put_battlefield(0, "Elvish Piper")
	var dragon := give_hand(0, "Shivan Dragon")
	add_mana(0, Mtg.ManaColor.G)
	p0.picks = [null]
	assert_ok(g.activate_ability(0, piper, 0))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.HAND)

func test_elvish_piper_needs_g_and_its_tap() -> void:
	var sick := put_battlefield(0, "Elvish Piper", true)
	var piper := put_battlefield(0, "Elvish Piper")
	give_hand(0, "Shivan Dragon")
	assert_refused(g.activate_ability(0, piper, 0), "mana")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, sick, 0))

## The human seat is asked at resolution; nothing moves until it answers.
func test_elvish_piper_holds_the_question_for_a_human() -> void:
	var piper := put_battlefield(0, "Elvish Piper")
	var dragon := give_hand(0, "Shivan Dragon")
	var wurm := give_hand(0, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.G)
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.activate_ability(0, piper, 0))
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice)
	assert_false(g.awaiting_choice.is_cost)
	assert_true(g.awaiting_choice.optional)
	assert_eq(dragon.zone, Mtg.Zone.HAND)
	assert_eq(wurm.zone, Mtg.Zone.HAND)
	assert_ok(g.answer_choice(wurm.id))
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dragon.zone, Mtg.Zone.HAND)


# --- Taunting Elf -----------------------------------------------------------

func test_taunting_elf_draws_every_able_blocker() -> void:
	var elf := put_battlefield(0, "Taunting Elf")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var tapped := put_battlefield(1, "Craw Wurm")
	g.tap_permanent(tapped)
	_attack(elf)
	assert_refused(g.declare_blockers(1, {}))
	assert_refused(g.declare_blockers(1, {bear.id: elf.id}))
	assert_ok(g.declare_blockers(1, {bear.id: elf.id, giant.id: elf.id}))


# --- Yavimaya Enchantress ---------------------------------------------------

func test_yavimaya_enchantress_grows_with_every_enchantment_on_the_battlefield() -> void:
	var enchantress := put_battlefield(0, "Yavimaya Enchantress")
	assert_eq([enchantress.cur_power, enchantress.cur_toughness], [2, 2])
	put_battlefield(0, "Crusade")
	assert_eq([enchantress.cur_power, enchantress.cur_toughness], [3, 3], "a white anthem still counts")
	var moon := put_battlefield(1, "Bad Moon")
	assert_eq([enchantress.cur_power, enchantress.cur_toughness], [4, 4], "theirs too")
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Holy Strength", [TargetRef.card(bear)])
	assert_eq([enchantress.cur_power, enchantress.cur_toughness], [5, 5], "an Aura is an enchantment")
	g.destroy(moon)
	assert_eq([enchantress.cur_power, enchantress.cur_toughness], [4, 4])
