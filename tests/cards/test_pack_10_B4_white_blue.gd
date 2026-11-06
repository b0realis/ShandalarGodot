extends GameTest
## Pack 10 (the Urza block), batch B4: the white and blue creatures of
## Urza's Legacy (cards/sets/ulg/_creatures.gd, _triggers.gd) and Wall of
## Glare (cards/sets/uds/_combat.gd) — Angelic Curator, Devout Harpist,
## Expendable Troops, Mother of Runes, Radiant, Archangel, Sustainer of the
## Realm, Tragic Poet, Wall of Glare, Anthroplasm, Archivist, Bouncing
## Beebles, Fleeting Image, King Crab, Thornwind Faeries, Walking Sponge.
## Each test drives the card through the public API and pins the clause
## that makes it that card, with its refused case.

const CLAIMED := ["Angelic Curator", "Devout Harpist", "Expendable Troops",
	"Mother of Runes", "Radiant, Archangel", "Sustainer of the Realm", "Tragic Poet",
	"Wall of Glare", "Anthroplasm", "Archivist", "Bouncing Beebles", "Fleeting Image",
	"King Crab", "Thornwind Faeries", "Walking Sponge"]


## FIFO answers; an empty queue falls back to the caller's hint (and a card
## pick to the first candidate).
class Scripted extends DecisionAgent:
	var colors: Array = []
	var options: Array = []
	var picks: Array = []

	func answer_color(_g: MtgGame, _p: int, _prompt: String, hint: int) -> int:
		return int(colors.pop_front()) if not colors.is_empty() else hint

	func answer_option(_g: MtgGame, _p: int, _prompt: String, _labels: Array[String], hint: int) -> int:
		return int(options.pop_front()) if not options.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if not picks.is_empty():
			var want: Variant = picks.pop_front()
			for c in candidates:
				if c == want:
					return c
		return null if candidates.is_empty() else candidates[0]


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

## Exactly the mana [param card]'s cost asks for.
func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

## [param pid] casts [param card_name] at [param targets]; the stack is kept.
func cast_only(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	return card

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	var card := cast_only(card_name, targets, pid)
	resolve_stack()
	return card

## A card [param card_name] in [param pid]'s graveyard.
func in_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := put_battlefield(pid, card_name)
	g.destroy(card)
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	return card

## P0 attacks with [param attackers]; P1 is to declare blockers.
func _attack(attackers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers:
		ids.append((a as CardInstance).id)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Angelic Curator -----------------------------------------------------------

func test_angelic_curator_cannot_be_targeted_by_an_artifact() -> void:
	var curator := put_battlefield(0, "Angelic Curator")
	var bear := put_battlefield(0, "Grizzly Bears")
	var rod := put_battlefield(1, "Rod of Ruin")
	assert_true(curator.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(1, rod, 0, [TargetRef.card(curator)]))
	assert_false(rod.tapped, "nothing paid for a refused target")
	assert_ok(g.activate_ability(1, rod, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 1, "the Rod still aims at anything else")

func test_angelic_curator_cannot_be_blocked_by_an_artifact_creature() -> void:
	var curator := put_battlefield(0, "Angelic Curator")
	var thopter := put_battlefield(1, "Ornithopter")
	var sprites := put_battlefield(1, "Scryb Sprites")
	_attack([curator])
	assert_refused(g.declare_blockers(1, {thopter.id: curator.id}))
	assert_ok(g.declare_blockers(1, {sprites.id: curator.id}))

func test_angelic_curator_is_not_protected_from_colored_sources() -> void:
	var curator := put_battlefield(0, "Angelic Curator")
	cast("Lightning Bolt", [TargetRef.card(curator)], 1)
	assert_eq(curator.zone, Mtg.Zone.GRAVEYARD)


# --- Devout Harpist -------------------------------------------------------------

func test_devout_harpist_destroys_an_aura_on_a_creature() -> void:
	var harpist := put_battlefield(0, "Devout Harpist")
	var bear := put_battlefield(1, "Grizzly Bears")
	var strength := cast("Unholy Strength", [TargetRef.card(bear)])
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	var crusade := put_battlefield(1, "Crusade")
	assert_refused(g.activate_ability(0, harpist, 0, [TargetRef.card(crusade)]))
	assert_refused(g.activate_ability(0, harpist, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, harpist, 0, [TargetRef.card(strength)]))
	assert_true(harpist.tapped)
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD)

func test_devout_harpist_leaves_an_aura_on_a_land_alone() -> void:
	var harpist := put_battlefield(0, "Devout Harpist")
	var forest := put_battlefield(1, "Forest")
	var growth := cast("Wild Growth", [TargetRef.card(forest)])
	assert_eq(growth.zone, Mtg.Zone.BATTLEFIELD)
	assert_refused(g.activate_ability(0, harpist, 0, [TargetRef.card(growth)]))


# --- Expendable Troops ---------------------------------------------------------

func test_expendable_troops_shoot_an_attacking_creature_only() -> void:
	var troops := put_battlefield(1, "Expendable Troops")
	var ogre := put_battlefield(0, "Gray Ogre")
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, troops, 0, [TargetRef.card(ogre)]), "")
	assert_eq(troops.zone, Mtg.Zone.BATTLEFIELD, "not in combat: nothing paid")
	assert_ok(g.pass_priority(1))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ogre.id]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, troops, 0, [TargetRef.card(ogre)]))
	assert_eq(troops.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is a cost")
	resolve_stack()
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD)


# --- Mother of Runes ------------------------------------------------------------

func test_mother_of_runes_grants_protection_from_the_chosen_color() -> void:
	var a := seat(0)
	var mother := put_battlefield(0, "Mother of Runes")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, mother, 0, [TargetRef.card(giant)]))
	a.colors = [Mtg.ManaColor.G]
	assert_ok(g.activate_ability(0, mother, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_protection, Mtg.ManaColor.G)
	advance_to_next_turn()
	assert_eq(bear.cur_protection, 0, "until end of turn")

func test_mother_of_runes_answers_a_bolt_with_protection_from_red() -> void:
	var mother := put_battlefield(0, "Mother of Runes")
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := cast_only("Lightning Bolt", [TargetRef.card(bear)], 1)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	# No scripted colour: the hint names the colour of the spell aimed at it.
	assert_ok(g.activate_ability(0, mother, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_protection, Mtg.ManaColor.R)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 0)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)

func test_mother_of_runes_holds_a_human_seat_on_the_color() -> void:
	var mother := put_battlefield(0, "Mother of Runes")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	assert_ok(g.activate_ability(0, mother, 0, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the colour is asked as it resolves")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.COLOR)
	assert_eq(bear.cur_protection, 0, "nothing granted while the question is open")
	assert_ok(g.answer_choice(Mtg.ManaColor.B))
	assert_null(g.awaiting_choice)
	assert_eq(bear.cur_protection, Mtg.ManaColor.B)


# --- Radiant, Archangel ---------------------------------------------------------

func test_radiant_counts_every_other_creature_with_flying() -> void:
	var radiant := put_battlefield(0, "Radiant, Archangel")
	assert_true(radiant.has_keyword(Mtg.Keyword.FLYING))
	assert_true(radiant.has_keyword(Mtg.Keyword.VIGILANCE))
	g.recalculate()
	assert_eq([radiant.cur_power, radiant.cur_toughness], [3, 3], "itself is not counted")
	put_battlefield(0, "Serra Angel")
	var sprites := put_battlefield(1, "Scryb Sprites")
	put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_eq([radiant.cur_power, radiant.cur_toughness], [5, 5], "both players' flyers, no walker")
	g.destroy(sprites)
	g.recalculate()
	assert_eq([radiant.cur_power, radiant.cur_toughness], [4, 4])

func test_radiant_sees_flying_granted_this_turn() -> void:
	var radiant := put_battlefield(0, "Radiant, Archangel")
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Jump", [TargetRef.card(bear)])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([radiant.cur_power, radiant.cur_toughness], [4, 4])


# --- Sustainer of the Realm -----------------------------------------------------

func test_sustainer_of_the_realm_grows_when_it_blocks() -> void:
	var sustainer := put_battlefield(1, "Sustainer of the Realm")
	var giant := put_battlefield(0, "Hill Giant")
	_attack([giant])
	assert_ok(g.declare_blockers(1, {sustainer.id: giant.id}))
	resolve_stack()
	assert_eq([sustainer.cur_power, sustainer.cur_toughness], [2, 5])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(sustainer.zone, Mtg.Zone.BATTLEFIELD, "3 damage on a 2/5")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_sustainer_of_the_realm_does_not_grow_when_it_attacks() -> void:
	var sustainer := put_battlefield(0, "Sustainer of the Realm")
	var spider := put_battlefield(1, "Giant Spider")
	_attack([sustainer])
	assert_ok(g.declare_blockers(1, {spider.id: sustainer.id}))
	resolve_stack()
	assert_eq([sustainer.cur_power, sustainer.cur_toughness], [2, 3])


# --- Tragic Poet ----------------------------------------------------------------

func test_tragic_poet_returns_an_enchantment_card_from_your_graveyard() -> void:
	var poet := put_battlefield(0, "Tragic Poet")
	var crusade := in_graveyard(0, "Crusade")
	var bear := in_graveyard(0, "Grizzly Bears")
	var theirs := in_graveyard(1, "Bad Moon")
	assert_refused(g.activate_ability(0, poet, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, poet, 0, [TargetRef.card(theirs)]))
	assert_eq(poet.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.activate_ability(0, poet, 0, [TargetRef.card(crusade)]))
	assert_eq(poet.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(crusade))


# --- Wall of Glare --------------------------------------------------------------

func test_wall_of_glare_blocks_any_number_of_creatures() -> void:
	var wall := put_battlefield(1, "Wall of Glare")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Llanowar Elves")
	var c := put_battlefield(0, "Llanowar Elves")
	assert_eq(g.blocks_allowed(wall), -1, "the first printed \"any number\"")
	_attack([a, b, c])
	assert_ok(g.declare_blockers(1, {wall.id: [a.id, b.id, c.id]}))
	assert_eq(g.combat.attackers_blocked_by(wall.id), [a.id, b.id, c.id] as Array[int])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "every attacker was blocked")
	assert_eq(wall.damage, 4)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)

func test_wall_of_glare_has_defender() -> void:
	var wall := put_battlefield(0, "Wall of Glare")
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [wall.id]))


# --- Anthroplasm ---------------------------------------------------------------

func test_anthroplasm_enters_with_two_counters() -> void:
	var plasm := cast("Anthroplasm")
	assert_eq(plasm.zone, Mtg.Zone.BATTLEFIELD, "the counters arrive with it")
	assert_eq(int(plasm.counters.get("+1/+1", 0)), 2)
	assert_eq([plasm.cur_power, plasm.cur_toughness], [2, 2])

func test_anthroplasm_resets_its_counters_to_x() -> void:
	var plasm := put_battlefield(0, "Anthroplasm")
	g.add_counters(plasm, "+1/+1", 3)
	assert_eq(int(plasm.counters.get("+1/+1", 0)), 5)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, plasm, 0, [], 1))
	assert_true(plasm.tapped)
	assert_eq(int(plasm.counters.get("+1/+1", 0)), 5, "the removal is the effect, not a cost")
	resolve_stack()
	assert_eq(int(plasm.counters.get("+1/+1", 0)), 1)
	assert_eq([plasm.cur_power, plasm.cur_toughness], [1, 1])
	assert_eq(plasm.zone, Mtg.Zone.BATTLEFIELD)

func test_anthroplasm_with_x_zero_dies() -> void:
	var plasm := put_battlefield(0, "Anthroplasm")
	assert_ok(g.activate_ability(0, plasm, 0, [], 0))
	resolve_stack()
	assert_eq(plasm.zone, Mtg.Zone.GRAVEYARD, "a 0/0 with no counters")


# --- Archivist -----------------------------------------------------------------

func test_archivist_draws_a_card() -> void:
	var archivist := put_battlefield(0, "Archivist")
	var sick := put_battlefield(0, "Archivist", true)
	var before := g.players[0].hand.size()
	assert_refused(g.activate_ability(0, sick, 0), "")
	assert_ok(g.activate_ability(0, archivist, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1)


# --- Bouncing Beebles -----------------------------------------------------------

func test_bouncing_beebles_cannot_be_blocked_while_the_defender_has_an_artifact() -> void:
	var beebles := put_battlefield(0, "Bouncing Beebles")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Sol Ring")
	g.recalculate()
	assert_true(beebles.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	_attack([beebles])
	assert_refused(g.declare_blockers(1, {bear.id: beebles.id}), "can't be blocked")

func test_bouncing_beebles_ignores_its_own_controllers_artifacts() -> void:
	var beebles := put_battlefield(0, "Bouncing Beebles")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Sol Ring")
	g.recalculate()
	assert_false(beebles.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	_attack([beebles])
	assert_ok(g.declare_blockers(1, {bear.id: beebles.id}))


# --- Fleeting Image ------------------------------------------------------------

func test_fleeting_image_returns_itself_to_its_owners_hand() -> void:
	var image := put_battlefield(0, "Fleeting Image")
	assert_true(image.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.activate_ability(0, image, 0), "")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, image, 0))
	assert_false(image.tapped, "no {T} in the cost")
	resolve_stack()
	assert_eq(image.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(image))


# --- King Crab -----------------------------------------------------------------

func test_king_crab_puts_a_green_creature_on_top_of_its_owners_library() -> void:
	var crab := put_battlefield(0, "King Crab")
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, crab, 0, [TargetRef.card(giant)]))
	assert_ok(g.activate_ability(0, crab, 0, [TargetRef.card(elves)]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library.back(), elves, "on top")


# --- Thornwind Faeries ---------------------------------------------------------

func test_thornwind_faeries_ping_any_target() -> void:
	var faeries := put_battlefield(0, "Thornwind Faeries")
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_true(faeries.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, faeries, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ok(g.activate_ability(0, faeries, 0, [TargetRef.card(elves)]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# --- Walking Sponge ------------------------------------------------------------

func test_walking_sponge_has_no_printed_keyword() -> void:
	var sponge := put_battlefield(0, "Walking Sponge")
	assert_false(sponge.has_keyword(Mtg.Keyword.FIRST_STRIKE), "its text names first strike; it has none")
	assert_eq(CardRegistry.get_card("Walking Sponge").keywords.size(), 0)

func test_walking_sponge_takes_the_chosen_keyword_until_end_of_turn() -> void:
	var a := seat(0)
	var sponge := put_battlefield(0, "Walking Sponge")
	var angel := put_battlefield(1, "Serra Angel")
	a.options = [0]
	assert_ok(g.activate_ability(0, sponge, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_true(angel.has_keyword(Mtg.Keyword.VIGILANCE), "only the chosen keyword")
	advance_to_next_turn()
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))

func test_walking_sponge_can_take_first_strike() -> void:
	var a := seat(0)
	var sponge := put_battlefield(0, "Walking Sponge")
	var knight := put_battlefield(1, "White Knight")
	a.options = [1]
	assert_ok(g.activate_ability(0, sponge, 0, [TargetRef.card(knight)]))
	resolve_stack()
	assert_false(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))

func test_walking_sponge_holds_a_human_seat_on_the_keyword() -> void:
	var sponge := put_battlefield(0, "Walking Sponge")
	var angel := put_battlefield(1, "Serra Angel")
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	assert_ok(g.activate_ability(0, sponge, 0, [TargetRef.card(angel)]))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the keyword is chosen as it resolves")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(g.awaiting_choice.options, ["Flying", "First strike", "Trample"])
	assert_ok(g.answer_choice(2))
	assert_null(g.awaiting_choice)
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING), "trample was chosen")
