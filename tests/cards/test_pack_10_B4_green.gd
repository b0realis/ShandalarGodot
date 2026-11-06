extends GameTest
## Pack 10 (the Urza block), batch B4: the green creatures of Urza's Legacy
## (cards/sets/ulg/_creatures.gd, _triggers.gd) and Thorn Elemental
## (cards/sets/uds/_combat.gd) — Gang of Elk, Multani, Maro-Sorcerer,
## Treefolk Mystic, Weatherseed Elf, Weatherseed Treefolk, Yavimaya Scion,
## Thorn Elemental. Each test drives the card through the public API and
## pins the clause that makes it that card, with its refused case.

const CLAIMED := ["Gang of Elk", "Multani, Maro-Sorcerer", "Treefolk Mystic",
	"Weatherseed Elf", "Weatherseed Treefolk", "Yavimaya Scion", "Thorn Elemental"]


class DamageChooser extends DecisionAgent:
	func wants_to_assign_combat_damage() -> bool: return true


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

## Exactly the mana [param card]'s cost asks for.
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


# --- Gang of Elk -----------------------------------------------------------------

func test_gang_of_elk_grows_two_two_for_each_blocker() -> void:
	var elk := put_battlefield(0, "Gang of Elk")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	_attack([elk])
	assert_ok(g.declare_blockers(1, {a.id: elk.id, b.id: elk.id}))
	resolve_stack()
	assert_eq([elk.cur_power, elk.cur_toughness], [9, 8], "every blocker, not only those beyond the first")

func test_gang_of_elk_unblocked_stays_as_printed() -> void:
	var elk := put_battlefield(0, "Gang of Elk")
	_attack([elk])
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq([elk.cur_power, elk.cur_toughness], [5, 4])


# --- Multani, Maro-Sorcerer --------------------------------------------------------

func test_multani_counts_every_card_in_every_hand() -> void:
	give_hand(0, "Lightning Bolt")
	give_hand(0, "Forest")
	give_hand(1, "Forest")
	var multani := put_battlefield(0, "Multani, Maro-Sorcerer")
	g.recalculate()
	assert_eq([multani.cur_power, multani.cur_toughness], [3, 3])
	var bolt: CardInstance = g.players[0].hand[0]
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq([multani.cur_power, multani.cur_toughness], [2, 2], "a card left a hand")
	resolve_stack()
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	g.recalculate()
	assert_eq([multani.cur_power, multani.cur_toughness], [4, 4], "the opponent's hand counts too")

func test_multani_in_a_hand_counts_itself() -> void:
	var multani := give_hand(0, "Multani, Maro-Sorcerer")
	give_hand(1, "Forest")
	g.recalculate()
	assert_eq([multani.cur_power, multani.cur_toughness], [2, 2])

func test_multani_has_shroud() -> void:
	give_hand(1, "Forest")
	var multani := put_battlefield(0, "Multani, Maro-Sorcerer")
	g.recalculate()
	assert_true(multani.cur_shroud)
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(multani)]))
	assert_eq(growth.zone, Mtg.Zone.HAND)

func test_multani_with_empty_hands_is_zero_zero() -> void:
	var multani := put_battlefield(0, "Multani, Maro-Sorcerer")
	g.recalculate()
	g.check_state_based_actions()
	assert_eq(multani.zone, Mtg.Zone.GRAVEYARD)


# --- Treefolk Mystic -------------------------------------------------------------

func test_treefolk_mystic_strips_the_auras_of_what_it_blocks() -> void:
	var mystic := put_battlefield(1, "Treefolk Mystic")
	var bear := put_battlefield(0, "Grizzly Bears")
	var strength := cast("Holy Strength", [TargetRef.card(bear)])
	var own := cast("Holy Strength", [TargetRef.card(mystic)])
	_attack([bear])
	assert_ok(g.declare_blockers(1, {mystic.id: bear.id}))
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(own.zone, Mtg.Zone.BATTLEFIELD, "only the other creature's Auras")

func test_treefolk_mystic_strips_the_auras_of_what_blocks_it() -> void:
	var mystic := put_battlefield(0, "Treefolk Mystic")
	var bear := put_battlefield(1, "Grizzly Bears")
	var strength := cast("Unholy Strength", [TargetRef.card(bear)])
	_attack([mystic])
	assert_ok(g.declare_blockers(1, {bear.id: mystic.id}))
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)


# --- Weatherseed Elf -------------------------------------------------------------

func test_weatherseed_elf_lends_forestwalk() -> void:
	var elf := put_battlefield(0, "Weatherseed Elf")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Llanowar Elves")
	put_battlefield(1, "Forest")
	assert_ok(g.activate_ability(0, elf, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("forest"))
	_attack([bear])
	assert_refused(g.declare_blockers(1, {blocker.id: bear.id}), "forestwalk")


# --- Weatherseed Treefolk --------------------------------------------------------

func test_weatherseed_treefolk_returns_to_hand_when_it_dies() -> void:
	var treefolk := put_battlefield(0, "Weatherseed Treefolk")
	assert_true(treefolk.has_keyword(Mtg.Keyword.TRAMPLE))
	g.destroy(treefolk)
	resolve_stack()
	assert_eq(treefolk.zone, Mtg.Zone.HAND)

func test_weatherseed_treefolk_bounced_is_not_a_death() -> void:
	var treefolk := put_battlefield(0, "Weatherseed Treefolk")
	g.return_permanent_to_library_top(treefolk)
	assert_true(g.stack.is_empty())
	assert_eq(treefolk.zone, Mtg.Zone.LIBRARY)


# --- Yavimaya Scion --------------------------------------------------------------

## Both rules presets: the 1997 damage-prevention step (Fifth Edition)
## does not turn protection into a choice — it prevents automatically.
func test_yavimaya_scion_takes_no_damage_from_an_artifact_creature() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var scion := put_battlefield(1, "Yavimaya Scion")
		var golem := put_battlefield(0, "Obsianus Golem")
		_attack([golem])
		assert_ok(g.declare_blockers(1, {scion.id: golem.id}))
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(scion.damage, 0, preset)
		assert_eq(golem.damage, 4, preset)

func test_yavimaya_scion_cannot_be_blocked_by_an_artifact_creature() -> void:
	var scion := put_battlefield(0, "Yavimaya Scion")
	var golem := put_battlefield(1, "Obsianus Golem")
	_attack([scion])
	assert_refused(g.declare_blockers(1, {golem.id: scion.id}))

func test_yavimaya_scion_cannot_be_targeted_by_an_artifact() -> void:
	var scion := put_battlefield(0, "Yavimaya Scion")
	var rod := put_battlefield(1, "Rod of Ruin")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(1, rod, 0, [TargetRef.card(scion)]))
	cast("Lightning Bolt", [TargetRef.card(scion)], 1)
	assert_eq(scion.damage, 3, "a red spell is no artifact")


# --- Thorn Elemental ------------------------------------------------------------

func test_thorn_elemental_may_hit_the_player_through_a_blocker() -> void:
	var thorn := put_battlefield(0, "Thorn Elemental")
	var wall := put_battlefield(1, "Wall of Stone")
	run_combat([thorn.id], {wall.id: thorn.id})
	assert_eq(g.players[1].life, 13)
	assert_eq(wall.damage, 0)

func test_thorn_elemental_may_also_hit_its_blocker() -> void:
	var thorn := put_battlefield(0, "Thorn Elemental")
	var wall := put_battlefield(1, "Wall of Stone")
	g.set_agent(0, DamageChooser.new())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [thorn.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: thorn.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment)
	assert_eq(g.damage_assignment_request().special, "bypass")
	assert_ok(g.assign_combat_damage(0, {wall.id: 7}))
	assert_eq(wall.damage, 7)
	assert_eq(g.players[1].life, 20)
